import Foundation

public struct RestartBackoff {
    private let base: TimeInterval
    private let max: TimeInterval
    private var attempt = 0

    public init(base: TimeInterval = 1, max: TimeInterval = 30) {
        self.base = base
        self.max = max
    }

    public mutating func nextDelay() -> TimeInterval {
        defer { attempt += 1 }
        return min(max, base * pow(2, Double(attempt)))
    }

    public mutating func reset() { attempt = 0 }
}
