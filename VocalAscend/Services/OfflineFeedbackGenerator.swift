import Foundation

/// Generates rule-based feedback when AI is unavailable
struct OfflineFeedbackGenerator {

    // MARK: - Feedback Generation

    /// Generate feedback for a single attempt
    static func generateFeedback(
        for attempt: AttemptMetrics,
        voiceProfile: VoiceProfile? = nil
    ) -> OfflineFeedback {
        var positives: [String] = []
        var improvements: [String] = []
        var tips: [String] = []
        var safetyNote: String? = nil

        // Analyze each aspect
        analyzeStability(attempt, positives: &positives, improvements: &improvements, tips: &tips)
        analyzePitchAccuracy(attempt, positives: &positives, improvements: &improvements, tips: &tips)
        analyzeHold(attempt, positives: &positives, improvements: &improvements, tips: &tips)
        analyzeStrain(attempt, safetyNote: &safetyNote, improvements: &improvements)
        analyzeConfidence(attempt, improvements: &improvements)

        // Profile-aware tips
        if let profile = voiceProfile {
            addProfileAwareTips(profile, attempt: attempt, tips: &tips)
        }

        // Generate headline based on overall performance
        let headline = generateHeadline(attempt)

        return OfflineFeedback(
            headline: headline,
            positives: positives,
            improvements: improvements,
            tips: tips,
            safetyNote: safetyNote
        )
    }

    /// Generate session summary feedback
    static func generateSessionSummary(
        attempts: [AttemptMetrics],
        duration: Int
    ) -> OfflineFeedback {
        var positives: [String] = []
        var improvements: [String] = []
        var tips: [String] = []
        var safetyNote: String? = nil

        let totalAttempts = attempts.count
        let successfulAttempts = attempts.filter { isSuccessful($0) }.count
        let avgStability = attempts.map { $0.stabilityScore }.average()
        let highStrainCount = attempts.filter { $0.strainLevel == .high }.count

        // Session-level feedback
        if totalAttempts > 0 {
            let successRate = Float(successfulAttempts) / Float(totalAttempts) * 100
            if successRate >= 70 {
                positives.append("Great session! \(Int(successRate))% of attempts were successful")
            } else if successRate >= 50 {
                positives.append("\(Int(successRate))% success rate - keep building consistency")
            } else {
                improvements.append("Focus on fewer, cleaner attempts next time")
            }
        }

        if avgStability >= 75 {
            positives.append("Excellent pitch stability averaging \(Int(avgStability))%")
        } else if avgStability >= 60 {
            tips.append("Work on sustaining notes longer to improve stability")
        } else {
            improvements.append("Stability needs work - try slower, more controlled exercises")
        }

        // Strain warnings
        if highStrainCount > 0 {
            safetyNote = "High strain detected \(highStrainCount) time(s). Tomorrow should be a lighter session."
        }

        // Duration feedback
        let minutes = duration / 60
        if minutes >= 20 && minutes <= 25 {
            positives.append("Perfect session length of \(minutes) minutes")
        } else if minutes < 15 {
            tips.append("Try to complete at least 15-20 minutes for optimal progress")
        } else if minutes > 30 {
            tips.append("Sessions over 30 minutes can lead to fatigue - quality over quantity")
        }

        let headline = highStrainCount > 0 ?
            "Session Complete - Rest Recommended" :
            "Session Complete - Good Work!"

        return OfflineFeedback(
            headline: headline,
            positives: positives,
            improvements: improvements,
            tips: tips,
            safetyNote: safetyNote
        )
    }

    // MARK: - Analysis Helpers

    private static func analyzeStability(
        _ attempt: AttemptMetrics,
        positives: inout [String],
        improvements: inout [String],
        tips: inout [String]
    ) {
        let stability = attempt.stabilityScore

        if stability >= 85 {
            positives.append("Excellent pitch stability at \(Int(stability))%")
        } else if stability >= 70 {
            positives.append("Good stability at \(Int(stability))%")
        } else if stability >= 50 {
            improvements.append("Pitch stability at \(Int(stability))% - aim for 70%+")
            tips.append("Try taking a slower breath before starting the note")
        } else {
            improvements.append("Pitch is wavering significantly")
            tips.append("Focus on breath support and don't push for volume")
        }
    }

    private static func analyzePitchAccuracy(
        _ attempt: AttemptMetrics,
        positives: inout [String],
        improvements: inout [String],
        tips: inout [String]
    ) {
        let centsOff = abs(attempt.avgCentsOff)

        if centsOff <= 10 {
            positives.append("Pitch accuracy is excellent - within 10 cents")
        } else if centsOff <= 25 {
            positives.append("Good pitch accuracy at \(Int(centsOff)) cents off")
        } else if centsOff <= 50 {
            improvements.append("Pitch is \(Int(centsOff)) cents off - aim for under 25")
            if attempt.avgCentsOff > 0 {
                tips.append("You're singing slightly sharp - try lightening up")
            } else {
                tips.append("You're singing slightly flat - check your breath support")
            }
        } else {
            improvements.append("Significant pitch deviation - slow down and focus on the target")
        }
    }

    private static func analyzeHold(
        _ attempt: AttemptMetrics,
        positives: inout [String],
        improvements: inout [String],
        tips: inout [String]
    ) {
        if attempt.holdSuccessful {
            positives.append("Held the note for 3+ seconds - great control!")
        } else if attempt.durationSeconds >= 2.0 {
            improvements.append("Almost there! Try to hold for 3 full seconds")
            tips.append("Relax your jaw and throat while sustaining")
        } else {
            tips.append("Practice sustaining notes longer - start with easier pitches")
        }
    }

    private static func analyzeStrain(
        _ attempt: AttemptMetrics,
        safetyNote: inout String?,
        improvements: inout [String]
    ) {
        switch attempt.strainLevel {
        case .high:
            safetyNote = "High strain detected. Stop and rest. If this continues, take a break day."
            improvements.append("You're pushing too hard - ease off and prioritize technique")
        case .medium:
            improvements.append("Moderate strain - try using less volume")
        case .low:
            // Slight strain is normal when developing
            break
        case .none:
            break
        }
    }

    private static func analyzeConfidence(
        _ attempt: AttemptMetrics,
        improvements: inout [String]
    ) {
        if attempt.confidence < 0.6 {
            improvements.append("Pitch detection was inconsistent - sing with more conviction")
        }
    }

    private static func addProfileAwareTips(
        _ profile: VoiceProfile,
        attempt: AttemptMetrics,
        tips: inout [String]
    ) {
        // Check if singing in developing range
        if let targetNote = Note.allCases.first(where: { $0.fullName == attempt.targetNote }),
           profile.isDeveloping(targetNote) {
            tips.append("This note is in your developing range - be patient with yourself")
        }

        // Vowel-specific tips based on profile tendencies
        if let spreadNote = profile.vowelSpreadAboveNote,
           let targetNote = Note.allCases.first(where: { $0.fullName == attempt.targetNote }),
           targetNote.midiNote >= spreadNote {
            tips.append("Remember to narrow your vowel on these higher notes")
        }
    }

    private static func generateHeadline(_ attempt: AttemptMetrics) -> String {
        if attempt.strainLevel == .high {
            return "Take It Easy"
        }

        if isSuccessful(attempt) {
            if attempt.holdSuccessful && attempt.stabilityScore >= 80 {
                return "Excellent Work!"
            } else if attempt.holdSuccessful {
                return "Good Progress!"
            } else {
                return "Nice Attempt!"
            }
        } else {
            if attempt.stabilityScore < 50 {
                return "Focus on Steadiness"
            } else if abs(attempt.avgCentsOff) > 25 {
                return "Work on Pitch Accuracy"
            } else {
                return "Keep Practicing!"
            }
        }
    }

    private static func isSuccessful(_ attempt: AttemptMetrics) -> Bool {
        return attempt.stabilityScore >= 70 &&
               abs(attempt.avgCentsOff) <= 25 &&
               attempt.strainLevel != .high &&
               attempt.confidence >= 0.6
    }
}

// MARK: - Offline Feedback Type

struct OfflineFeedback {
    let headline: String
    let positives: [String]
    let improvements: [String]
    let tips: [String]
    let safetyNote: String?

    /// Convert to format compatible with AI coach response
    func toCoachResponse() -> AIResponseParser.CoachResponse {
        AIResponseParser.CoachResponse(
            headline: headline,
            whatWentWell: positives.isEmpty ? ["Keep practicing!"] : positives,
            fixNext: improvements.isEmpty ? tips : improvements,
            nextDrill: nil,
            safetyNote: safetyNote
        )
    }
}

// MARK: - Array Extension

extension Array where Element == Float {
    func average() -> Float {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Float(count)
    }
}
