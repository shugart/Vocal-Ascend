import Foundation
import SwiftData

/// Evaluates whether progression gates have been met for note unlocks
/// Based on recent performance data
final class ProgressionGateEvaluator {

    // MARK: - Gate Results

    struct GateResult {
        let gate: ProgressionGate
        let isMet: Bool
        let details: [String: Any]
        let blockers: [String]
    }

    enum ProgressionGate {
        case a4Introduction
        case aSharp4Introduction
    }

    // MARK: - A4 Gate Requirements (Phase 1 → Phase 2)

    /// Gate to Introduce A4:
    /// - G#4 hold pass rate (7d) ≥ 60%
    /// - G#4 avg stability (7d) ≥ 70
    /// - Strain red count (7d) == 0
    func evaluateA4Gate(
        attempts: [ExerciseAttempt],
        voiceProfile: VoiceProfile,
        lookbackDays: Int = 7
    ) -> GateResult {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()

        // Filter recent attempts targeting G#4
        let recentAttempts = attempts.filter { attempt in
            attempt.createdAt >= cutoffDate &&
            (attempt.targetNote == "G#4" || attempt.targetNote == "GS4")
        }

        var blockers: [String] = []

        // Check hold pass rate
        let holdAttempts = recentAttempts.filter { $0.durationSeconds >= 3.0 }
        let holdPassRate: Float
        if recentAttempts.isEmpty {
            holdPassRate = 0
            blockers.append("No G#4 attempts in last \(lookbackDays) days")
        } else {
            holdPassRate = Float(holdAttempts.count) / Float(recentAttempts.count) * 100
            if holdPassRate < 60 {
                blockers.append("Hold pass rate \(Int(holdPassRate))% (need 60%)")
            }
        }

        // Check average stability
        let avgStability: Float
        if recentAttempts.isEmpty {
            avgStability = 0
        } else {
            avgStability = recentAttempts.map { $0.stabilityScore }.reduce(0, +) / Float(recentAttempts.count)
            if avgStability < 70 {
                blockers.append("Avg stability \(Int(avgStability)) (need 70)")
            }
        }

        // Check strain red count
        let strainRedCount = recentAttempts.filter { $0.strainLevelEnum == .high }.count
        if strainRedCount > 0 {
            blockers.append("\(strainRedCount) high strain event(s) in last \(lookbackDays) days")
        }

        // Also check profile's last high strain date
        if let lastStrain = voiceProfile.lastHighStrainDate,
           lastStrain >= cutoffDate {
            if !blockers.contains(where: { $0.contains("high strain") }) {
                blockers.append("High strain detected on \(formatDate(lastStrain))")
            }
        }

        let isMet = holdPassRate >= 60 && avgStability >= 70 && strainRedCount == 0

        return GateResult(
            gate: .a4Introduction,
            isMet: isMet,
            details: [
                "holdPassRate": holdPassRate,
                "avgStability": avgStability,
                "strainRedCount": strainRedCount,
                "attemptCount": recentAttempts.count
            ],
            blockers: blockers
        )
    }

    // MARK: - A#4 Gate Requirements (Phase 2 → Phase 3)

    /// Gate to Introduce A#4:
    /// - A4 hold pass rate (7d) ≥ 70%
    /// - A4 avg stability (7d) ≥ 75
    /// - Strain red count (14d) == 0
    /// - A4 max hold (7d) ≥ 3s
    func evaluateASharp4Gate(
        attempts: [ExerciseAttempt],
        voiceProfile: VoiceProfile
    ) -> GateResult {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        // Filter recent attempts targeting A4
        let recentA4Attempts = attempts.filter { attempt in
            attempt.createdAt >= sevenDaysAgo &&
            attempt.targetNote == "A4"
        }

        // Filter 14-day attempts for strain check
        let twoWeekAttempts = attempts.filter { $0.createdAt >= fourteenDaysAgo }

        var blockers: [String] = []

        // Check hold pass rate
        let holdAttempts = recentA4Attempts.filter { $0.durationSeconds >= 3.0 }
        let holdPassRate: Float
        if recentA4Attempts.isEmpty {
            holdPassRate = 0
            blockers.append("No A4 attempts in last 7 days")
        } else {
            holdPassRate = Float(holdAttempts.count) / Float(recentA4Attempts.count) * 100
            if holdPassRate < 70 {
                blockers.append("Hold pass rate \(Int(holdPassRate))% (need 70%)")
            }
        }

        // Check average stability
        let avgStability: Float
        if recentA4Attempts.isEmpty {
            avgStability = 0
        } else {
            avgStability = recentA4Attempts.map { $0.stabilityScore }.reduce(0, +) / Float(recentA4Attempts.count)
            if avgStability < 75 {
                blockers.append("Avg stability \(Int(avgStability)) (need 75)")
            }
        }

        // Check max hold duration
        let maxHold = recentA4Attempts.map { $0.durationSeconds }.max() ?? 0
        if maxHold < 3.0 {
            blockers.append("Max hold \(String(format: "%.1f", maxHold))s (need 3.0s)")
        }

        // Check strain red count (14 days)
        let strainRedCount = twoWeekAttempts.filter { $0.strainLevelEnum == .high }.count
        if strainRedCount > 0 {
            blockers.append("\(strainRedCount) high strain event(s) in last 14 days")
        }

        // Also check profile's last high strain date
        if let lastStrain = voiceProfile.lastHighStrainDate,
           lastStrain >= fourteenDaysAgo {
            if !blockers.contains(where: { $0.contains("high strain") }) {
                blockers.append("High strain detected on \(formatDate(lastStrain))")
            }
        }

        let isMet = holdPassRate >= 70 && avgStability >= 75 && maxHold >= 3.0 && strainRedCount == 0

        return GateResult(
            gate: .aSharp4Introduction,
            isMet: isMet,
            details: [
                "holdPassRate": holdPassRate,
                "avgStability": avgStability,
                "maxHold": maxHold,
                "strainRedCount": strainRedCount,
                "attemptCount": recentA4Attempts.count
            ],
            blockers: blockers
        )
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
