import Foundation

/// Parses and validates AI coach responses
struct AIResponseParser {

    // MARK: - Response Types

    struct CoachResponse: Codable {
        let headline: String
        let whatWentWell: [String]
        let fixNext: [String]
        let nextDrill: NextDrill?
        let safetyNote: String?

        enum CodingKeys: String, CodingKey {
            case headline
            case whatWentWell = "what_went_well"
            case fixNext = "fix_next"
            case nextDrill = "next_drill"
            case safetyNote = "safety_note"
        }
    }

    struct NextDrill: Codable {
        let exerciseId: String?
        let targetNote: String?
        let targetVowel: String?
        let reps: Int?
        let cue: String?

        enum CodingKeys: String, CodingKey {
            case exerciseId = "exercise_id"
            case targetNote = "target_note"
            case targetVowel = "target_vowel"
            case reps
            case cue
        }
    }

    enum ParseError: LocalizedError {
        case noContent
        case invalidJSON(String)
        case missingRequiredFields([String])
        case unexpectedFormat(String)

        var errorDescription: String? {
            switch self {
            case .noContent:
                return "The AI response was empty"
            case .invalidJSON(let details):
                return "Could not parse AI response as JSON: \(details)"
            case .missingRequiredFields(let fields):
                return "AI response missing required fields: \(fields.joined(separator: ", "))"
            case .unexpectedFormat(let details):
                return "Unexpected response format: \(details)"
            }
        }
    }

    // MARK: - Parsing

    /// Parse a JSON response from the AI
    static func parse(_ jsonString: String) -> Result<CoachResponse, ParseError> {
        // Clean up the response - sometimes AI wraps in markdown code blocks
        let cleaned = cleanJSONString(jsonString)

        guard !cleaned.isEmpty else {
            return .failure(.noContent)
        }

        guard let data = cleaned.data(using: .utf8) else {
            return .failure(.invalidJSON("Could not convert to data"))
        }

        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(CoachResponse.self, from: data)
            return .success(response)
        } catch let error as DecodingError {
            return .failure(.invalidJSON(describeDecodingError(error)))
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    /// Validate that a response has all required content
    static func validate(_ response: CoachResponse) -> Result<CoachResponse, ParseError> {
        var missingFields: [String] = []

        if response.headline.isEmpty {
            missingFields.append("headline")
        }

        if response.whatWentWell.isEmpty {
            missingFields.append("what_went_well")
        }

        if response.fixNext.isEmpty {
            missingFields.append("fix_next")
        }

        if !missingFields.isEmpty {
            return .failure(.missingRequiredFields(missingFields))
        }

        return .success(response)
    }

    /// Try to repair a malformed JSON response
    static func attemptRepair(_ jsonString: String) -> String? {
        var cleaned = cleanJSONString(jsonString)

        // Try to extract JSON from mixed content
        if let jsonStart = cleaned.firstIndex(of: "{"),
           let jsonEnd = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[jsonStart...jsonEnd])
        }

        // Try to fix common issues
        cleaned = cleaned
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: ",]", with: "]")
            .replacingOccurrences(of: ",}", with: "}")

        // Validate it's parseable
        if let data = cleaned.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            return cleaned
        }

        return nil
    }

    // MARK: - Private Helpers

    private static func cleanJSONString(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing key: \(key.stringValue)"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
        case .valueNotFound(let type, let context):
            return "Null value for \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}

// MARK: - CoachResponse Extensions

extension AIResponseParser.CoachResponse {

    /// Convert next drill suggestion to app types
    var nextDrillNote: Note? {
        guard let noteString = nextDrill?.targetNote else { return nil }
        let normalized = noteString.replacingOccurrences(of: "#", with: "S")
        return Note(rawValue: normalized)
    }

    var nextDrillVowel: Vowel? {
        guard let vowelString = nextDrill?.targetVowel else { return nil }
        return Vowel(rawValue: vowelString)
    }
}
