import Foundation
import Combine

/// Client for OpenAI API communication
final class OpenAIService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isLoading = false
    @Published private(set) var lastError: OpenAIError?

    // MARK: - Types

    enum OpenAIError: LocalizedError {
        case noAPIKey
        case invalidURL
        case networkError(Error)
        case httpError(Int, String?)
        case decodingError(Error)
        case rateLimited
        case timeout
        case offline

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenAI API key not configured"
            case .invalidURL:
                return "Invalid API URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code, let message):
                return "HTTP \(code): \(message ?? "Unknown error")"
            case .decodingError(let error):
                return "Response parsing error: \(error.localizedDescription)"
            case .rateLimited:
                return "Rate limited. Please try again later."
            case .timeout:
                return "Request timed out"
            case .offline:
                return "No internet connection"
            }
        }
    }

    // MARK: - Configuration

    struct Config {
        var apiEndpoint: String = "https://api.openai.com/v1/chat/completions"
        var model: String = "gpt-4"
        var temperature: Double = 0.7
        var maxTokens: Int = 1000
        var timeoutSeconds: TimeInterval = 30
    }

    var config = Config()

    // MARK: - Private Properties

    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "openAIKey")
    }

    private let session: URLSession

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// Check if the service is configured and ready
    var isConfigured: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        return true
    }

    /// Check if we're online
    var isOnline: Bool {
        // Simple connectivity check - in production, use NWPathMonitor
        return true
    }

    /// Send a chat completion request
    func chat(
        systemPrompt: String,
        userMessage: String
    ) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw OpenAIError.noAPIKey
        }

        guard let url = URL(string: config.apiEndpoint) else {
            throw OpenAIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = config.timeoutSeconds

        let body = ChatCompletionRequest(
            model: config.model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userMessage)
            ],
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )

        request.httpBody = try JSONEncoder().encode(body)

        // Update state on main thread
        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // Make request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.networkError(NSError(domain: "", code: -1))
            }

            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 429:
                throw OpenAIError.rateLimited
            default:
                let errorMessage = String(data: data, encoding: .utf8)
                throw OpenAIError.httpError(httpResponse.statusCode, errorMessage)
            }

            // Decode response
            let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

            guard let content = chatResponse.choices.first?.message.content else {
                throw OpenAIError.decodingError(NSError(domain: "", code: -1))
            }

            return content

        } catch let error as OpenAIError {
            await MainActor.run { lastError = error }
            throw error
        } catch let error as URLError {
            let aiError: OpenAIError
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                aiError = .offline
            case .timedOut:
                aiError = .timeout
            default:
                aiError = .networkError(error)
            }
            await MainActor.run { lastError = aiError }
            throw aiError
        } catch {
            let aiError = OpenAIError.networkError(error)
            await MainActor.run { lastError = aiError }
            throw aiError
        }
    }

    /// Analyze an attempt and get coaching feedback
    func analyzeAttempt(
        voiceProfile: VoiceProfile,
        attempt: AttemptMetrics,
        exerciseName: String
    ) async throws -> AIResponseParser.CoachResponse {
        let userPrompt = PromptBuilder.buildAttemptAnalysisPrompt(
            voiceProfile: voiceProfile,
            attempt: attempt,
            exerciseName: exerciseName
        )

        let responseText = try await chat(
            systemPrompt: PromptBuilder.systemPrompt,
            userMessage: userPrompt
        )

        // Parse the response
        let parseResult = AIResponseParser.parse(responseText)

        switch parseResult {
        case .success(let response):
            // Validate the response
            let validateResult = AIResponseParser.validate(response)
            switch validateResult {
            case .success(let validated):
                return validated
            case .failure(let error):
                throw error
            }

        case .failure(let error):
            // Try to repair the response
            if let repaired = AIResponseParser.attemptRepair(responseText) {
                let retryResult = AIResponseParser.parse(repaired)
                if case .success(let response) = retryResult {
                    return response
                }
            }
            throw error
        }
    }

    /// Get session summary feedback
    func summarizeSession(
        voiceProfile: VoiceProfile,
        attempts: [AttemptMetrics],
        duration: Int,
        dayType: DayType
    ) async throws -> AIResponseParser.CoachResponse {
        let userPrompt = PromptBuilder.buildSessionSummaryPrompt(
            voiceProfile: voiceProfile,
            sessionAttempts: attempts,
            sessionDuration: duration,
            dayType: dayType
        )

        let responseText = try await chat(
            systemPrompt: PromptBuilder.systemPrompt,
            userMessage: userPrompt
        )

        let parseResult = AIResponseParser.parse(responseText)

        switch parseResult {
        case .success(let response):
            return response
        case .failure(let error):
            if let repaired = AIResponseParser.attemptRepair(responseText),
               case .success(let response) = AIResponseParser.parse(repaired) {
                return response
            }
            throw error
        }
    }
}

// MARK: - API Request/Response Types

private struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Codable {
    let id: String
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
    }
}
