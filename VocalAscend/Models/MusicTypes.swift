import Foundation

// MARK: - Note

/// Represents musical notes from A2 to C5 (supported vocal range for the app)
enum Note: String, CaseIterable, Codable, Hashable {
    case A2, AS2, B2
    case C3, CS3, D3, DS3, E3, F3, FS3, G3, GS3, A3, AS3, B3
    case C4, CS4, D4, DS4, E4, F4, FS4, G4, GS4, A4, AS4, B4
    case C5

    /// Reference frequency for A4 (configurable, default 440 Hz)
    static var referenceA4Hz: Float = 440.0

    /// The supported range of notes for this app (A2 to C5)
    static var supportedRange: [Note] {
        return Note.allCases
    }

    /// MIDI note number (A4 = 69)
    var midiNote: Int {
        switch self {
        case .A2: return 45
        case .AS2: return 46
        case .B2: return 47
        case .C3: return 48
        case .CS3: return 49
        case .D3: return 50
        case .DS3: return 51
        case .E3: return 52
        case .F3: return 53
        case .FS3: return 54
        case .G3: return 55
        case .GS3: return 56
        case .A3: return 57
        case .AS3: return 58
        case .B3: return 59
        case .C4: return 60
        case .CS4: return 61
        case .D4: return 62
        case .DS4: return 63
        case .E4: return 64
        case .F4: return 65
        case .FS4: return 66
        case .G4: return 67
        case .GS4: return 68
        case .A4: return 69
        case .AS4: return 70
        case .B4: return 71
        case .C5: return 72
        }
    }

    /// Frequency in Hz based on equal temperament
    var frequency: Float {
        // f = 440 * 2^((n-69)/12) where n is MIDI note number
        let semitonesFromA4 = Float(midiNote - 69)
        return Note.referenceA4Hz * pow(2.0, semitonesFromA4 / 12.0)
    }

    /// The octave number (e.g., 4 for A4)
    var octave: Int {
        return (midiNote / 12) - 1
    }

    /// Whether this is a sharp/flat note
    var isSharp: Bool {
        return rawValue.contains("S")
    }

    /// Display name (e.g., "A#" for AS4)
    var displayName: String {
        let name = rawValue.dropLast() // Remove octave digit
        return String(name).replacingOccurrences(of: "S", with: "#")
    }

    /// Full display name with octave (e.g., "A#4")
    var fullName: String {
        return "\(displayName)\(octave)"
    }

    /// Find the nearest note to a given frequency
    static func nearest(to frequency: Float) -> (note: Note, centsOff: Float)? {
        guard frequency > 0 else { return nil }

        // Calculate the MIDI note number (can be fractional)
        let midiFloat = 69.0 + 12.0 * log2(Double(frequency) / Double(referenceA4Hz))
        let nearestMidi = Int(round(midiFloat))

        // Find the Note enum case matching this MIDI number
        guard let note = Note.allCases.first(where: { $0.midiNote == nearestMidi }) else {
            return nil
        }

        // Calculate cents offset (-50 to +50)
        let centsOff = Float((midiFloat - Double(nearestMidi)) * 100.0)

        return (note, centsOff)
    }

    /// Calculate cents offset from this note to a given frequency
    func centsOffset(from frequency: Float) -> Float {
        guard frequency > 0 else { return 0 }
        let semitones = 12.0 * log2(Double(frequency) / Double(self.frequency))
        return Float(semitones * 100.0)
    }

    /// Get a note by semitone offset from this note
    func transposed(by semitones: Int) -> Note? {
        let targetMidi = midiNote + semitones
        return Note.allCases.first { $0.midiNote == targetMidi }
    }
}

// MARK: - Vowel

/// Vowel sounds used in vocal exercises
enum Vowel: String, CaseIterable, Codable, Hashable {
    case AH
    case EH
    case EE
    case OH
    case OO
    case UH
    case NG
    case MM
    case NEI
    case GEE
    case GUH

    /// Display label for the vowel
    var label: String {
        switch self {
        case .AH: return "Ah"
        case .EH: return "Eh"
        case .EE: return "Ee"
        case .OH: return "Oh"
        case .OO: return "Oo"
        case .UH: return "Uh"
        case .NG: return "Ng"
        case .MM: return "Mm"
        case .NEI: return "Ney"
        case .GEE: return "Gee"
        case .GUH: return "Guh"
        }
    }

    /// Whether this is a "narrower" vowel (helpful for high notes)
    var isNarrow: Bool {
        switch self {
        case .OO, .UH, .OH, .NG, .MM:
            return true
        default:
            return false
        }
    }
}

// MARK: - Exercise Category

enum ExerciseCategory: String, CaseIterable, Codable {
    case warmup
    case mix
    case belt
    case skill
    case recovery
    case cooldown

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .warmup: return "flame"
        case .mix: return "slider.horizontal.3"
        case .belt: return "speaker.wave.3"
        case .skill: return "target"
        case .recovery: return "leaf"
        case .cooldown: return "snowflake"
        }
    }
}

// MARK: - Day Type

enum DayType: String, Codable {
    case build
    case light
    case assessment
    case performance

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Strain Level

enum StrainLevel: String, Codable, Comparable {
    case none
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    static func < (lhs: StrainLevel, rhs: StrainLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Attempt Metrics

/// Summary of metrics captured during a vocal exercise attempt
struct AttemptMetrics: Codable, Hashable {
    /// Target note for the attempt
    let targetNote: String

    /// Target vowel (if applicable)
    let targetVowel: String?

    /// Achieved note (most frequently detected)
    let achievedNote: String?

    /// Average cents offset from target
    let avgCentsOff: Float

    /// Stability score (0-100)
    let stabilityScore: Float

    /// Average RMS loudness
    let avgLoudness: Float

    /// Peak dBFS
    let peakDBFS: Float

    /// Duration in seconds
    let durationSeconds: Float

    /// Whether the hold threshold was met
    let holdSuccessful: Bool

    /// Detected strain level
    let strainLevel: StrainLevel

    /// Confidence score (0-1)
    let confidence: Float
}

// MARK: - Pitch Frame

/// Real-time pitch data from the audio engine
struct PitchFrame {
    let timestamp: Date
    let f0Hz: Float?
    let noteName: String?
    let octave: Int?
    let centsOffNearest: Float?
    let centsOffTarget: Float?
    let confidence: Float
    let rms: Float
    let dbfs: Float

    /// Whether the pitch detection is reliable
    var isReliable: Bool {
        confidence >= 0.6 && f0Hz != nil
    }
}
