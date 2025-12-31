import XCTest
@testable import VocalAscend

final class PitchDetectorTests: XCTestCase {

    var pitchDetector: PitchDetector!
    let sampleRate: Float = 44100.0

    override func setUp() {
        super.setUp()
        pitchDetector = PitchDetector()
    }

    override func tearDown() {
        pitchDetector = nil
        super.tearDown()
    }

    // MARK: - Sine Wave Tests

    func testDetectA4SineWave() {
        // A4 = 440 Hz
        let samples = PitchDetector.generateSineWave(
            frequency: 440.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertNotNil(frequency, "Should detect frequency")
        XCTAssertGreaterThan(confidence, 0.8, "Should have high confidence for pure sine")

        if let freq = frequency {
            let centsOff = 1200 * log2(freq / 440.0)
            XCTAssertLessThan(abs(centsOff), 10, "Should be within 10 cents of A4")
        }
    }

    func testDetectC4SineWave() {
        // C4 = 261.63 Hz
        let samples = PitchDetector.generateSineWave(
            frequency: 261.63,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertNotNil(frequency, "Should detect frequency")
        XCTAssertGreaterThan(confidence, 0.8, "Should have high confidence")

        if let freq = frequency {
            let centsOff = 1200 * log2(freq / 261.63)
            XCTAssertLessThan(abs(centsOff), 10, "Should be within 10 cents of C4")
        }
    }

    func testDetectG4SineWave() {
        // G4 = 392 Hz
        let samples = PitchDetector.generateSineWave(
            frequency: 392.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertNotNil(frequency, "Should detect frequency")

        if let freq = frequency {
            let centsOff = 1200 * log2(freq / 392.0)
            XCTAssertLessThan(abs(centsOff), 10, "Should be within 10 cents of G4")
        }
    }

    // MARK: - Harmonic Tests (More Realistic Voice)

    func testDetectA4WithHarmonics() {
        let samples = PitchDetector.generateSineWithHarmonics(
            fundamental: 440.0,
            sampleRate: sampleRate,
            duration: 0.1
        )

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertNotNil(frequency, "Should detect fundamental with harmonics")
        XCTAssertGreaterThan(confidence, 0.6, "Should have reasonable confidence")

        if let freq = frequency {
            let centsOff = 1200 * log2(freq / 440.0)
            XCTAssertLessThan(abs(centsOff), 25, "Should be within 25 cents of A4")
        }
    }

    func testDetectLowNotesC3() {
        // C3 = 130.81 Hz (lower male range)
        let samples = PitchDetector.generateSineWithHarmonics(
            fundamental: 130.81,
            sampleRate: sampleRate,
            duration: 0.15
        )

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertNotNil(frequency, "Should detect low frequencies")

        if let freq = frequency {
            let centsOff = 1200 * log2(freq / 130.81)
            XCTAssertLessThan(abs(centsOff), 25, "Should be within 25 cents of C3")
        }
    }

    // MARK: - Edge Cases

    func testSilenceReturnsNil() {
        let samples = [Float](repeating: 0, count: 2048)

        let (frequency, confidence) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)

        // Should return nil or very low confidence for silence
        if let _ = frequency {
            XCTAssertLessThan(confidence, 0.3, "Silence should have low confidence")
        }
    }

    func testVeryShortBufferHandled() {
        let samples = PitchDetector.generateSineWave(
            frequency: 440.0,
            sampleRate: sampleRate,
            duration: 0.01 // Very short
        )

        // Should not crash
        let (_, _) = pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - Note Conversion Tests

    func testNoteNearestToA4() {
        let result = Note.nearest(to: 440.0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.note, .A4)
        XCTAssertLessThan(abs(result?.centsOff ?? 100), 1, "Should be exactly on A4")
    }

    func testNoteNearestToFlatA4() {
        // Slightly flat A4 (430 Hz = about -40 cents)
        let result = Note.nearest(to: 430.0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.note, .A4)
        XCTAssertLessThan(result?.centsOff ?? 0, 0, "Should be flat (negative cents)")
    }

    func testNoteNearestToSharpA4() {
        // Slightly sharp A4 (450 Hz = about +39 cents)
        let result = Note.nearest(to: 450.0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.note, .A4)
        XCTAssertGreaterThan(result?.centsOff ?? 0, 0, "Should be sharp (positive cents)")
    }

    // MARK: - Note Frequency Tests

    func testNoteFrequencies() {
        XCTAssertEqual(Note.A4.frequency, 440.0, accuracy: 0.1)
        XCTAssertEqual(Note.A3.frequency, 220.0, accuracy: 0.1)
        XCTAssertEqual(Note.A2.frequency, 110.0, accuracy: 0.1)
    }
}
