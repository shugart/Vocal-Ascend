import Foundation
import SwiftData

@Model
final class VoiceProfile {
    // MARK: - Basic Info
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    /// User's age (optional, for AI coaching context)
    var age: Int?

    /// Voice type tag (e.g., "baritone", "tenor")
    var voiceTypeTag: String?

    // MARK: - Range Settings
    /// Lowest comfortable note (MIDI number)
    var comfortableLowNote: Int

    /// Highest comfortable note (MIDI number)
    var comfortableHighNote: Int

    /// Notes currently being developed (stored as comma-separated MIDI numbers)
    var developingNotes: String

    // MARK: - Thresholds
    /// Cents tolerance for "in tune" (default 25)
    var stableCentsTolerance: Float

    /// Minimum pitch confidence to consider valid (default 0.6)
    var minConfidence: Float

    // MARK: - Tendencies (stored as JSON)
    /// Note above which user tends to spread vowels
    var vowelSpreadAboveNote: Int?

    /// Note above which user tends to pull chest voice
    var chestPullAboveNote: Int?

    /// Preferred coaching cues (stored as JSON array)
    var preferredCuesJSON: String?

    // MARK: - Performance Stats (stored as JSON)
    /// Per-note/vowel performance stats
    var performanceStatsJSON: String?

    // MARK: - Safety
    /// Strain risk sensitivity (low, medium, high)
    var strainRiskSensitivity: String

    /// Last date when high strain was detected
    var lastHighStrainDate: Date?

    /// Baseline loudness at comfortable note (for strain detection)
    var baselineLoudnessDBFS: Float?

    // MARK: - Initializer

    init(
        comfortableLowNote: Int = 48, // C3
        comfortableHighNote: Int = 64, // E4
        stableCentsTolerance: Float = 25,
        minConfidence: Float = 0.6
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.comfortableLowNote = comfortableLowNote
        self.comfortableHighNote = comfortableHighNote
        self.developingNotes = ""
        self.stableCentsTolerance = stableCentsTolerance
        self.minConfidence = minConfidence
        self.strainRiskSensitivity = "medium"
    }

    // MARK: - Computed Properties

    var comfortableLowNoteEnum: Note? {
        Note.allCases.first { $0.midiNote == comfortableLowNote }
    }

    var comfortableHighNoteEnum: Note? {
        Note.allCases.first { $0.midiNote == comfortableHighNote }
    }

    var developingNotesArray: [Note] {
        guard !developingNotes.isEmpty else { return [] }
        let midiNumbers = developingNotes.split(separator: ",").compactMap { Int($0) }
        return midiNumbers.compactMap { midi in
            Note.allCases.first { $0.midiNote == midi }
        }
    }

    // MARK: - Methods

    func addDevelopingNote(_ note: Note) {
        var notes = developingNotesArray
        if !notes.contains(note) {
            notes.append(note)
            developingNotes = notes.map { String($0.midiNote) }.joined(separator: ",")
            updatedAt = Date()
        }
    }

    func removeDevelopingNote(_ note: Note) {
        var notes = developingNotesArray
        notes.removeAll { $0 == note }
        developingNotes = notes.map { String($0.midiNote) }.joined(separator: ",")
        updatedAt = Date()
    }

    func isInComfortableRange(_ note: Note) -> Bool {
        note.midiNote >= comfortableLowNote && note.midiNote <= comfortableHighNote
    }

    func isDeveloping(_ note: Note) -> Bool {
        developingNotesArray.contains(note)
    }

    func rangeZone(for note: Note) -> RangeZone {
        if isInComfortableRange(note) {
            return .comfortable
        } else if isDeveloping(note) {
            return .developing
        } else {
            return .strain
        }
    }

    func recordHighStrain() {
        lastHighStrainDate = Date()
        updatedAt = Date()
    }
}

// MARK: - Performance Stats

struct NotePerformanceStats: Codable {
    var note: String
    var vowel: String?
    var bestStabilityScore: Float
    var avgCentsOff: Float
    var maxSustainSeconds: Float
    var attemptCount: Int
    var lastAttemptDate: Date?

    mutating func update(with metrics: AttemptMetrics) {
        attemptCount += 1
        lastAttemptDate = Date()

        if metrics.stabilityScore > bestStabilityScore {
            bestStabilityScore = metrics.stabilityScore
        }

        if metrics.durationSeconds > maxSustainSeconds {
            maxSustainSeconds = metrics.durationSeconds
        }

        // Rolling average for cents offset
        let totalCents = avgCentsOff * Float(attemptCount - 1) + metrics.avgCentsOff
        avgCentsOff = totalCents / Float(attemptCount)
    }
}
