import Foundation
import SwiftData

@Model
final class AICoachMessage {
    var id: UUID
    var createdAt: Date

    /// Role: "user" or "assistant"
    var role: String

    /// The message content (for user messages, this is the prompt type)
    var content: String

    /// Parsed AI response JSON (for assistant messages)
    var responseJSON: String?

    /// Linked session ID (optional)
    var linkedSessionId: UUID?

    /// Linked attempt ID (optional)
    var linkedAttemptId: UUID?

    /// Whether the message was successfully processed
    var isComplete: Bool

    /// Error message if processing failed
    var errorMessage: String?

    init(role: String, content: String, linkedSessionId: UUID? = nil, linkedAttemptId: UUID? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.role = role
        self.content = content
        self.linkedSessionId = linkedSessionId
        self.linkedAttemptId = linkedAttemptId
        self.isComplete = false
    }

    // MARK: - Computed Properties

    var isUserMessage: Bool {
        role == "user"
    }

    var isAssistantMessage: Bool {
        role == "assistant"
    }

    var parsedResponse: AICoachResponse? {
        guard let responseJSON,
              let data = responseJSON.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AICoachResponse.self, from: data)
    }

    // MARK: - Methods

    func setResponse(_ response: AICoachResponse) {
        if let data = try? JSONEncoder().encode(response),
           let json = String(data: data, encoding: .utf8) {
            self.responseJSON = json
            self.isComplete = true
        }
    }

    func setError(_ message: String) {
        self.errorMessage = message
        self.isComplete = true
    }
}

// MARK: - AI Coach Response Structure

struct AICoachResponse: Codable {
    let headline: String
    let whatWentWell: [String]
    let fixNext: [String]
    let nextDrill: NextDrillSuggestion?
    let safetyNote: String?

    enum CodingKeys: String, CodingKey {
        case headline
        case whatWentWell = "what_went_well"
        case fixNext = "fix_next"
        case nextDrill = "next_drill"
        case safetyNote = "safety_note"
    }
}

struct NextDrillSuggestion: Codable {
    let exerciseId: String
    let targetNote: String
    let targetVowel: String?
    let reps: Int
    let cue: String

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case targetNote = "target_note"
        case targetVowel = "target_vowel"
        case reps
        case cue
    }
}

// MARK: - Message Types

enum AICoachMessageType: String {
    case analyzeAttempt = "analyze_attempt"
    case suggestPlan = "suggest_plan"
    case generalQuestion = "general_question"

    var displayName: String {
        switch self {
        case .analyzeAttempt: return "Analyze Last Attempt"
        case .suggestPlan: return "Suggest Tomorrow's Plan"
        case .generalQuestion: return "Ask a Question"
        }
    }
}
