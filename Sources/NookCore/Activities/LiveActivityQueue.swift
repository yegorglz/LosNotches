import Foundation

public struct LiveActivity: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: LiveActivityKind
    public var revision: Int
    public var expiresAt: Date?
    public var peekText: String?

    public init(id: String, kind: LiveActivityKind, revision: Int = 0, expiresAt: Date? = nil, peekText: String? = nil) {
        self.id = id
        self.kind = kind
        self.revision = revision
        self.expiresAt = expiresAt
        self.peekText = peekText
    }
}

public struct LiveActivityQueue: Equatable, Sendable {
    private var entries: [String: (activity: LiveActivity, seq: Int)] = [:]
    private var dismissed: [String: Int] = [:]
    private var seq = 0

    public init() {}

    public static func == (a: Self, b: Self) -> Bool {
        a.dismissed == b.dismissed && a.entries.mapValues(\.activity) == b.entries.mapValues(\.activity)
    }

    public var all: [LiveActivity] { entries.values.map(\.activity) }

    public mutating func upsert(_ a: LiveActivity) {
        seq += 1
        entries[a.id] = (a, seq)
    }

    public mutating func remove(id: String) {
        entries[id] = nil
        dismissed[id] = nil
    }

    public mutating func dismiss(id: String) {
        if let e = entries[id] { dismissed[id] = e.activity.revision }
    }

    public mutating func purgeExpired(now: Date) {
        for (id, e) in entries where (e.activity.expiresAt.map { $0 <= now } ?? false) { remove(id: id) }
    }

    public func current(now: Date, isFullscreen: Bool, settings: LiveActivitiesSettings) -> LiveActivity? {
        guard settings.enabled else { return nil }
        return entries.values
            .filter { e in
                let a = e.activity
                if !settings.enabledKinds.contains(a.kind) { return false }
                if let exp = a.expiresAt, exp <= now { return false }
                if isFullscreen, !settings.visibleInFullscreen.contains(a.kind) { return false }
                if let rev = dismissed[a.id], !settings.unhideAutomatically || rev == a.revision { return false }
                return true
            }
            .max { ($0.activity.kind.priority, $0.seq) < ($1.activity.kind.priority, $1.seq) }?
            .activity
    }
}
