import Accelerate
import Foundation

/// YIN pitch detection algorithm implementation
/// Based on: "YIN, a fundamental frequency estimator for speech and music"
/// by Alain de Cheveigné and Hideki Kawahara (2002)
final class PitchDetector {

    // MARK: - Configuration

    /// Minimum frequency to detect (Hz) - approximately A2
    private let minFrequency: Float = 80.0

    /// Maximum frequency to detect (Hz) - approximately C5
    private let maxFrequency: Float = 600.0

    /// YIN threshold for pitch detection (lower = stricter)
    private let threshold: Float = 0.15

    // MARK: - Public Methods

    /// Detect pitch from audio samples
    /// - Parameters:
    ///   - samples: Audio samples (mono, float)
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Tuple of (frequency in Hz or nil, confidence 0-1)
    func detectPitch(samples: [Float], sampleRate: Float) -> (frequency: Float?, confidence: Float) {
        let count = samples.count

        // Calculate lag range based on frequency range
        let minLag = Int(sampleRate / maxFrequency)
        let maxLag = min(count / 2, Int(sampleRate / minFrequency))

        guard maxLag > minLag else {
            return (nil, 0)
        }

        // Step 1: Calculate difference function
        let difference = calculateDifference(samples: samples, maxLag: maxLag)

        // Step 2: Calculate cumulative mean normalized difference function (CMNDF)
        let cmndf = calculateCMNDF(difference: difference)

        // Step 3: Find the first minimum below threshold (absolute threshold)
        guard let (lag, minValue) = findBestLag(cmndf: cmndf, minLag: minLag, maxLag: maxLag) else {
            return (nil, 0)
        }

        // Step 4: Parabolic interpolation for sub-sample accuracy
        let refinedLag = refineWithParabolicInterpolation(cmndf: cmndf, lag: lag)

        // Calculate frequency
        let frequency = sampleRate / refinedLag

        // Calculate confidence (inverse of CMNDF minimum value)
        let confidence = 1.0 - min(1.0, minValue)

        // Validate frequency range
        guard frequency >= minFrequency && frequency <= maxFrequency else {
            return (nil, 0)
        }

        return (frequency, confidence)
    }

    // MARK: - Private Methods

    /// Step 1: Calculate the difference function d(τ)
    /// d(τ) = Σ (x[j] - x[j+τ])²
    private func calculateDifference(samples: [Float], maxLag: Int) -> [Float] {
        let count = samples.count
        var difference = [Float](repeating: 0, count: maxLag)

        // For each lag τ
        for tau in 0..<maxLag {
            var sum: Float = 0

            // Sum of squared differences
            let windowSize = count - maxLag
            for j in 0..<windowSize {
                let diff = samples[j] - samples[j + tau]
                sum += diff * diff
            }

            difference[tau] = sum
        }

        return difference
    }

    /// Step 2: Calculate cumulative mean normalized difference function (CMNDF)
    /// d'(τ) = d(τ) / ((1/τ) * Σ d(j)) for j = 1 to τ
    /// This normalizes the difference function to help find the true period
    private func calculateCMNDF(difference: [Float]) -> [Float] {
        var cmndf = [Float](repeating: 0, count: difference.count)

        // d'(0) = 1 by definition
        cmndf[0] = 1.0

        var runningSum: Float = 0

        for tau in 1..<difference.count {
            runningSum += difference[tau]

            if runningSum > 0 {
                cmndf[tau] = difference[tau] * Float(tau) / runningSum
            } else {
                cmndf[tau] = 1.0
            }
        }

        return cmndf
    }

    /// Step 3: Find the first lag where CMNDF dips below threshold
    /// This implements "absolute threshold" from the YIN paper
    private func findBestLag(cmndf: [Float], minLag: Int, maxLag: Int) -> (lag: Int, value: Float)? {
        var bestLag: Int?
        var bestValue: Float = Float.greatestFiniteMagnitude

        // Find first dip below threshold
        for tau in minLag..<maxLag {
            if cmndf[tau] < threshold {
                // Found a candidate - now find the local minimum
                while tau + 1 < maxLag && cmndf[tau + 1] < cmndf[tau] {
                    // Keep going until we find the local minimum
                    break
                }

                // Find local minimum in this region
                var localMin = tau
                for t in tau..<min(tau + 5, maxLag) {
                    if cmndf[t] < cmndf[localMin] {
                        localMin = t
                    }
                }

                return (localMin, cmndf[localMin])
            }
        }

        // If no value below threshold, find the global minimum
        for tau in minLag..<maxLag {
            if cmndf[tau] < bestValue {
                bestValue = cmndf[tau]
                bestLag = tau
            }
        }

        // Only return if the minimum is reasonably low
        if let lag = bestLag, bestValue < 0.5 {
            return (lag, bestValue)
        }

        return nil
    }

    /// Step 4: Parabolic interpolation for sub-sample accuracy
    private func refineWithParabolicInterpolation(cmndf: [Float], lag: Int) -> Float {
        guard lag > 0 && lag < cmndf.count - 1 else {
            return Float(lag)
        }

        let y0 = cmndf[lag - 1]
        let y1 = cmndf[lag]
        let y2 = cmndf[lag + 1]

        let offset = DSPUtils.parabolicInterpolation(y0: y0, y1: y1, y2: y2)

        return Float(lag) + offset
    }
}

// MARK: - Pitch Detector Tests Support

extension PitchDetector {
    /// Generate a sine wave for testing
    static func generateSineWave(
        frequency: Float,
        sampleRate: Float,
        duration: Float,
        amplitude: Float = 0.8
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        let angularFrequency = 2.0 * Float.pi * frequency / sampleRate

        for i in 0..<sampleCount {
            samples[i] = amplitude * sin(angularFrequency * Float(i))
        }

        return samples
    }

    /// Generate a sine wave with harmonics (more realistic voice)
    static func generateSineWithHarmonics(
        fundamental: Float,
        sampleRate: Float,
        duration: Float,
        harmonics: [(multiplier: Float, amplitude: Float)] = [
            (1.0, 1.0),
            (2.0, 0.5),
            (3.0, 0.3),
            (4.0, 0.15)
        ]
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)

        for (multiplier, amplitude) in harmonics {
            let frequency = fundamental * multiplier
            let angularFrequency = 2.0 * Float.pi * frequency / sampleRate

            for i in 0..<sampleCount {
                samples[i] += amplitude * sin(angularFrequency * Float(i))
            }
        }

        // Normalize
        let maxVal = samples.max() ?? 1.0
        if maxVal > 0 {
            for i in 0..<sampleCount {
                samples[i] /= maxVal
                samples[i] *= 0.8 // Scale to 80%
            }
        }

        return samples
    }
}
