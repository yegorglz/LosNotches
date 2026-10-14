public struct ScreenDiff: Equatable, Sendable {
    public var added: [UInt32]
    public var removed: [UInt32]
    public var changed: [UInt32]

    public init(added: [UInt32], removed: [UInt32], changed: [UInt32]) {
        self.added = added
        self.removed = removed
        self.changed = changed
    }

    public static func compute(old: [ScreenMetrics], new: [ScreenMetrics]) -> ScreenDiff {
        let o = Dictionary(old.map { ($0.displayID, $0) }, uniquingKeysWith: { a, _ in a })
        let n = Dictionary(new.map { ($0.displayID, $0) }, uniquingKeysWith: { a, _ in a })
        return ScreenDiff(
            added: n.keys.filter { o[$0] == nil }.sorted(),
            removed: o.keys.filter { n[$0] == nil }.sorted(),
            changed: n.keys.filter { o[$0] != nil && o[$0] != n[$0] }.sorted()
        )
    }
}
