import Foundation

public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isStarred: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var archived: Bool
}

public struct TodoList: Codable, Equatable, Sendable {
    public var items: [TodoItem] = []
    public init() {}

    @discardableResult
    public mutating func add(title: String, now: Date) -> TodoItem? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let item = TodoItem(id: UUID(), title: t, isStarred: false, createdAt: now, completedAt: nil, archived: false)
        items.append(item)
        return item
    }

    public mutating func toggleStar(id: UUID) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].isStarred.toggle() }
    }

    public mutating func toggleComplete(id: UUID, now: Date) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].completedAt = items[i].completedAt == nil ? now : nil }
    }

    public mutating func delete(id: UUID) { items.removeAll { $0.id == id } }

    public mutating func archiveCompleted(olderThan: TimeInterval = 86_400, now: Date) {
        for i in items.indices where (items[i].completedAt.map { now.timeIntervalSince($0) > olderThan } ?? false) {
            items[i].archived = true
        }
    }

    public func visible() -> [TodoItem] {
        let live = items.filter { !$0.archived }
        let open = live.filter { $0.completedAt == nil }.sorted { $0.createdAt < $1.createdAt }
        let done = live.filter { $0.completedAt != nil }.sorted { $0.completedAt! > $1.completedAt! }
        return open.filter(\.isStarred) + open.filter { !$0.isStarred } + done
    }
}
