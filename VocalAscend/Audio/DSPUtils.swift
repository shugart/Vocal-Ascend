import Accelerate
import Foundation

/// Digital Signal Processing utilities for audio analysis
enum DSPUtils {

    // MARK: - RMS and Loudness

    /// Calculate Root Mean Square (RMS) of audio samples using vDSP
    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    /// Convert RMS to dBFS (decibels relative to full scale)
    /// Full scale is 1.0, so dBFS = 20 * log10(rms)
    static func rmsToDBFS(_ rms: Float) -> Float {
        guard rms > 0 else { return -Float.infinity }
        let dbfs = 20.0 * log10(rms)
        // Clamp to reasonable range
        return max(-60, min(0, dbfs))
    }

    /// Calculate dBFS directly from samples
    static func calculateDBFS(_ samples: [Float]) -> Float {
        let rms = calculateRMS(samples)
        return rmsToDBFS(rms)
    }

    // MARK: - Stability

    /// Calculate pitch stability score (0-100) from recent frequency readings
    /// Higher score = more stable pitch
    static func calculatePitchStability(_ frequencies: [Float]) -> Float {
        guard frequencies.count >= 2 else { return 0 }

        // Convert to cents (logarithmic scale for musical perception)
        let cents = frequencies.map { 1200.0 * log2($0 / 440.0) }

        // Calculate standard deviation
        var mean: Float = 0
        var stdDev: Float = 0
        vDSP_normalize(cents, 1, nil, 1, &mean, &stdDev, vDSP_Length(cents.count))

        // Convert std dev to stability score
        // 0 cents std dev = 100% stable
        // 50 cents std dev = 0% stable
        let stability = max(0, min(100, 100 - (stdDev * 2)))
        return stability
    }

    // MARK: - Windowing Functions

    /// Apply Hanning window to samples (in-place)
    static func applyHanningWindow(_ samples: inout [Float]) {
        let count = samples.count
        guard count > 0 else { return }

        var window = [Float](repeating: 0, count: count)
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))

        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(count))
    }

    /// Create and apply Hanning window, returning new array
    static func hanningWindow(_ samples: [Float]) -> [Float] {
        var result = samples
        applyHanningWindow(&result)
        return result
    }

    // MARK: - Autocorrelation

    /// Calculate autocorrelation using simple time-domain method
    /// Returns array where index i represents correlation at lag i
    static func autocorrelation(_ samples: [Float]) -> [Float] {
        let count = samples.count
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0, count: count)

        // Simple time-domain autocorrelation
        for lag in 0..<count {
            var sum: Float = 0
            for i in 0..<(count - lag) {
                sum += samples[i] * samples[i + lag]
            }
            result[lag] = sum
        }

        return result
    }

    // MARK: - Peak Detection

    /// Find local maximum in array within given range
    static func findPeak(in array: [Float], from start: Int, to end: Int) -> (index: Int, value: Float)? {
        guard start >= 0, end <= array.count, start < end else { return nil }

        var maxIndex = start
        var maxValue = array[start]

        for i in start..<end {
            if array[i] > maxValue {
                maxValue = array[i]
                maxIndex = i
            }
        }

        return (maxIndex, maxValue)
    }

    /// Parabolic interpolation for sub-sample peak refinement
    /// Returns interpolated peak position (fractional index)
    static func parabolicInterpolation(y0: Float, y1: Float, y2: Float) -> Float {
        let denominator = y0 - 2 * y1 + y2
        guard abs(denominator) > Float.ulpOfOne else { return 0 }
        return 0.5 * (y0 - y2) / denominator
    }

    // MARK: - Frequency Helpers

    /// Convert sample index (lag) to frequency
    static func lagToFrequency(lag: Float, sampleRate: Float) -> Float {
        guard lag > 0 else { return 0 }
        return sampleRate / lag
    }

    /// Convert frequency to sample index (lag)
    static func frequencyToLag(frequency: Float, sampleRate: Float) -> Float {
        guard frequency > 0 else { return 0 }
        return sampleRate / frequency
    }

    // MARK: - Utility

    /// Zero-crossing rate (useful for voice activity detection)
    static func zeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }

        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) ||
               (samples[i] < 0 && samples[i-1] >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(samples.count - 1)
    }

    /// Downsample audio by a factor (simple averaging)
    static func downsample(_ samples: [Float], factor: Int) -> [Float] {
        guard factor > 1 else { return samples }

        let newCount = samples.count / factor
        var result = [Float](repeating: 0, count: newCount)

        for i in 0..<newCount {
            var sum: Float = 0
            for j in 0..<factor {
                sum += samples[i * factor + j]
            }
            result[i] = sum / Float(factor)
        }

        return result
    }
}
