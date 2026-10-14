public struct PowerSnapshot: Equatable, Sendable {
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var percent: Int
    public var isCharged: Bool
    public init(isPluggedIn: Bool, isCharging: Bool, percent: Int, isCharged: Bool) {
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.percent = percent
        self.isCharged = isCharged
    }
}

public enum BatteryEvent: Equatable, Sendable {
    case pluggedIn(percent: Int), unplugged(percent: Int), full, low(percent: Int)
}

/// Emits battery events only on transitions, never on plain percent changes.
public struct BatteryTransitionDetector {
    public var lowThreshold: Int
    private var previous: PowerSnapshot?
    private var fullAnnounced = false

    public init(lowThreshold: Int) { self.lowThreshold = lowThreshold }

    public mutating func ingest(_ s: PowerSnapshot) -> BatteryEvent? {
        defer { previous = s }
        let isFull = s.isCharged || s.percent >= 100
        guard let p = previous else {
            fullAnnounced = s.isPluggedIn && isFull
            return nil
        }
        if s.isPluggedIn != p.isPluggedIn {
            fullAnnounced = false
            return s.isPluggedIn ? .pluggedIn(percent: s.percent) : .unplugged(percent: s.percent)
        }
        if s.isPluggedIn {
            if isFull, !fullAnnounced { fullAnnounced = true; return .full }
            return nil
        }
        if p.percent > lowThreshold, s.percent <= lowThreshold { return .low(percent: s.percent) }
        return nil
    }
}
