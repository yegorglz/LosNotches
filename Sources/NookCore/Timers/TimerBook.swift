import Foundation

public enum TimerState: Codable, Equatable, Sendable {
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case finished
}

public struct TimerEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var duration: TimeInterval
    public var state: TimerState
}

public struct TimerBook: Codable, Equatable, Sendable {
    public var entries: [TimerEntry] = []
    public init() {}

    @discardableResult
    public mutating func start(duration: TimeInterval, label: String, now: Date) -> TimerEntry? {
        guard duration > 0 else { return nil }
        let e = TimerEntry(id: UUID(), label: label, duration: duration, state: .running(endDate: now + duration))
        entries.append(e)
        return e
    }

    public mutating func pause(id: UUID, now: Date) {
        update(id) { if case .running(let end) = $0.state { $0.state = .paused(remaining: max(0, end.timeIntervalSince(now))) } }
    }

    public mutating func resume(id: UUID, now: Date) {
        update(id) { if case .paused(let r) = $0.state { $0.state = .running(endDate: now + r) } }
    }

    public mutating func restart(id: UUID, now: Date) {
        update(id) { $0.state = .running(endDate: now + $0.duration) }
    }

    public mutating func cancel(id: UUID) { entries.removeAll { $0.id == id } }

    public func remaining(id: UUID, now: Date) -> TimeInterval {
        guard let e = entries.first(where: { $0.id == id }) else { return 0 }
        switch e.state {
        case .running(let end): return max(0, end.timeIntervalSince(now))
        case .paused(let r): return r
        case .finished: return 0
        }
    }

    public mutating func collectFinished(now: Date) -> [TimerEntry] {
        var done: [TimerEntry] = []
        for i in entries.indices {
            if case .running(let end) = entries[i].state, end <= now {
                entries[i].state = .finished
                done.append(entries[i])
            }
        }
        return done
    }

    public func soonestRunning(now: Date) -> TimerEntry? {
        entries.compactMap { e -> (TimerEntry, Date)? in
            if case .running(let end) = e.state, end > now { return (e, end) } else { return nil }
        }.min { $0.1 < $1.1 }?.0
    }

    /// The timer the notch shows: soonest running, else a paused one (so it can be resumed from the notch).
    public func displayed(now: Date) -> TimerEntry? {
        soonestRunning(now: now) ?? entries.first { if case .paused = $0.state { true } else { false } }
    }

    private mutating func update(_ id: UUID, _ f: (inout TimerEntry) -> Void) {
        if let i = entries.firstIndex(where: { $0.id == id }) { f(&entries[i]) }
    }
}

public enum TimerWheel {
    public static let presets: [TimeInterval] = [60, 300, 600, 1500]
    public static func seconds(h: Int, m: Int, s: Int) -> TimeInterval { TimeInterval(h * 3600 + m * 60 + s) }
    public static func components(_ t: TimeInterval) -> (h: Int, m: Int, s: Int) {
        let total = Int(t)
        return (total / 3600, total % 3600 / 60, total % 60)
    }
}

public enum DurationText {
    public static func format(_ t: TimeInterval) -> String {
        guard t > 0 else { return "0:00" }
        let total = Int(t.rounded(.up))
        let (h, m, s) = (total / 3600, total % 3600 / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
