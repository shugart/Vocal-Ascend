import Foundation

/// Builds prompts for the AI coach based on user data and attempt metrics
struct PromptBuilder {

    // MARK: - System Prompt

    static let systemPrompt = """
    You are a friendly, encouraging vocal coach for the Vocal Ascend app. You help male singers safely develop their mix voice and belt coordination up to A#4/Bb4.

    CRITICAL SAFETY GUIDELINES:
    - You are NOT a medical professional and cannot provide medical advice
    - If a user reports pain, hoarseness, or discomfort, immediately recommend they stop and consult a doctor or ENT
    - Always prioritize vocal health over pushing for higher notes
    - Recommend rest when appropriate
    - Keep content appropriate for teenage users

    COACHING STYLE:
    - Be encouraging but honest about technique
    - Focus on what went well before suggesting improvements
    - Keep suggestions actionable and specific
    - Use simple, clear language
    - Limit to 2-3 improvement suggestions at a time

    RESPONSE FORMAT:
    Always respond in this exact JSON format:
    {
        "headline": "A brief, encouraging headline (max 10 words)",
        "what_went_well": ["1-3 specific positive observations"],
        "fix_next": ["1-3 specific, actionable improvement suggestions"],
        "next_drill": {
            "exercise_id": "exercise ID from the library or null",
            "target_note": "note like A4 or null",
            "target_vowel": "vowel like UH or null",
            "reps": number or null,
            "cue": "a specific technique cue to focus on"
        },
        "safety_note": "any safety concerns or null if none"
    }
    """

    // MARK: - Attempt Analysis Prompt

    static func buildAttemptAnalysisPrompt(
        voiceProfile: VoiceProfile,
        attempt: AttemptMetrics,
        exerciseName: String
    ) -> String {
        let profileSummary = buildProfileSummary(voiceProfile)
        let attemptSummary = buildAttemptSummary(attempt, exerciseName: exerciseName)

        return """
        \(profileSummary)

        ## Latest Attempt
        \(attemptSummary)

        Please analyze this attempt and provide coaching feedback in the specified JSON format.
        """
    }

    // MARK: - Session Summary Prompt

    static func buildSessionSummaryPrompt(
        voiceProfile: VoiceProfile,
        sessionAttempts: [AttemptMetrics],
        sessionDuration: Int,
        dayType: DayType
    ) -> String {
        let profileSummary = buildProfileSummary(voiceProfile)

        var attemptsSummary = ""
        for (index, attempt) in sessionAttempts.enumerated() {
            attemptsSummary += """

            Attempt \(index + 1):
            - Target: \(attempt.targetNote)\(attempt.targetVowel.map { " on \($0)" } ?? "")
            - Stability: \(Int(attempt.stabilityScore))%
            - Cents off: \(Int(attempt.avgCentsOff))
            - Hold successful: \(attempt.holdSuccessful)
            - Strain: \(attempt.strainLevel.displayName)
            """
        }

        return """
        \(profileSummary)

        ## Today's Session (\(dayType.displayName) Day)
        Duration: \(sessionDuration / 60) minutes
        Attempts: \(sessionAttempts.count)
        \(attemptsSummary)

        Please provide an overall session summary and recommendations for tomorrow.
        """
    }

    // MARK: - Plan Suggestion Prompt

    static func buildPlanSuggestionPrompt(
        voiceProfile: VoiceProfile,
        planProgress: UserPlanProgress,
        recentStats: RecentPerformanceStats
    ) -> String {
        let profileSummary = buildProfileSummary(voiceProfile)

        return """
        \(profileSummary)

        ## Training Progress
        - Current Phase: \(planProgress.currentPhase)
        - Week: \(planProgress.currentWeek)
        - Training Days: \(planProgress.trainingDaysCompleted)
        - Current Streak: \(planProgress.currentStreak) days
        - A4 Unlocked: \(planProgress.a4Unlocked)
        - A#4 Unlocked: \(planProgress.aSharp4Unlocked)

        ## Recent Performance (7 days)
        - Avg Stability on \(recentStats.targetNote.fullName): \(Int(recentStats.avgStability))%
        - Hold Pass Rate: \(Int(recentStats.holdPassRate))%
        - High Strain Events: \(recentStats.strainRedCount)

        Based on this progress, suggest adjustments to tomorrow's training if any.
        """
    }

    // MARK: - Private Helpers

    private static func buildProfileSummary(_ profile: VoiceProfile) -> String {
        let lowNote = profile.comfortableLowNoteEnum?.fullName ?? "C3"
        let highNote = profile.comfortableHighNoteEnum?.fullName ?? "E4"
        let developing = profile.developingNotesArray.map { $0.fullName }.joined(separator: ", ")

        return """
        ## Singer Profile
        - Comfortable Range: \(lowNote) to \(highNote)
        - Developing Notes: \(developing.isEmpty ? "None yet" : developing)
        - Voice Type: \(profile.voiceTypeTag ?? "Not specified")
        - Strain Sensitivity: \(profile.strainRiskSensitivity)
        """
    }

    private static func buildAttemptSummary(_ attempt: AttemptMetrics, exerciseName: String) -> String {
        return """
        - Exercise: \(exerciseName)
        - Target Note: \(attempt.targetNote)\(attempt.targetVowel.map { " on '\($0)'" } ?? "")
        - Achieved Note: \(attempt.achievedNote ?? "Not detected")
        - Stability Score: \(Int(attempt.stabilityScore))%
        - Cents Off Target: \(Int(attempt.avgCentsOff))
        - Duration: \(String(format: "%.1f", attempt.durationSeconds))s
        - Hold Successful (3s+): \(attempt.holdSuccessful ? "Yes" : "No")
        - Peak Loudness: \(Int(attempt.peakDBFS)) dBFS
        - Strain Level: \(attempt.strainLevel.displayName)
        - Confidence: \(Int(attempt.confidence * 100))%
        """
    }
}

// MARK: - Recent Performance Stats

struct RecentPerformanceStats {
    let targetNote: Note
    let avgStability: Float
    let holdPassRate: Float
    let strainRedCount: Int
    let attemptCount: Int
}
