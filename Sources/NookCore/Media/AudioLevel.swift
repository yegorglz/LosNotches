import Foundation

/// Turns raw audio samples into a 0...1 "how loud is it now" value for the media effects.
public struct AudioLevel {
    public private(set) var value: Float = 0

    public init() {}

    /// Maps RMS to 0...1 on a −50…0 dBFS scale (roughly how loud it sounds).
    public static func normalized(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db + 50) / 50))
    }

    public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Fast attack, slow release, so bars jump on beats and fall back smoothly.
    public mutating func ingest(rms: Float) {
        let target = Self.normalized(rms: rms)
        value += (target - value) * (target > value ? 0.6 : 0.12)
    }
}
