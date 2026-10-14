import Foundation

public struct TrayItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var bookmark: Data
    public var displayName: String
    public var addedAt: Date
    public var isOwnedCopy: Bool
}

public protocol FileBookmarking {
    func bookmark(for url: URL) throws -> Data
    func resolve(_ data: Data) -> URL?
}

public struct SystemBookmarking: FileBookmarking {
    public init() {}
    public func bookmark(for url: URL) throws -> Data { try url.bookmarkData() }
    public func resolve(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withoutUI], bookmarkDataIsStale: &stale)
    }
}

/// Files kept near the notch. References survive renames (bookmarks); moved/pasted files live under `Files/`.
public final class TrayStore {
    public private(set) var items: [TrayItem]
    private let directory: URL
    private let bookmarking: FileBookmarking
    private let now: () -> Date
    private let store: JSONFileStore<[TrayItem]>
    private let discard: (URL) throws -> Void

    /// `discard` disposes of owned copies on removal; by default they go to the Trash (an ⌥-dragged file is the user's original).
    public init(directory: URL, bookmarking: FileBookmarking = SystemBookmarking(), now: @escaping () -> Date = Date.init,
                discard: @escaping (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
        self.directory = directory
        self.bookmarking = bookmarking
        self.now = now
        self.discard = discard
        store = JSONFileStore(url: directory.appendingPathComponent("tray.json")) { [] }
        items = store.load()
        pruneMissing()
    }

    @discardableResult
    public func add(_ urls: [URL], move: Bool) throws -> [TrayItem] {
        var added: [TrayItem] = []
        defer { persist() } // keep files already handled even if a later one fails
        for url in urls {
            let path = url.resolvingSymlinksInPath().path
            if let i = items.firstIndex(where: { self.url(for: $0.id)?.resolvingSymlinksInPath().path == path }) {
                let existing = items.remove(at: i)
                items.insert(existing, at: 0)
                added.append(existing)
                continue
            }
            let id = UUID()
            var target = url
            if move {
                target = try ownedFolder(id).appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: target)
            }
            let bookmark: Data
            do {
                bookmark = try bookmarking.bookmark(for: target)
            } catch {
                if move { try? FileManager.default.moveItem(at: target, to: url) } // never orphan a moved file
                throw error
            }
            let item = TrayItem(id: id, bookmark: bookmark, displayName: url.lastPathComponent, addedAt: now(), isOwnedCopy: move)
            items.insert(item, at: 0)
            added.append(item)
        }
        return added
    }

    @discardableResult
    public func addData(_ data: Data, suggestedName: String) throws -> TrayItem {
        let id = UUID()
        let target = try ownedFolder(id).appendingPathComponent(suggestedName)
        try data.write(to: target, options: .atomic)
        let item = TrayItem(id: id, bookmark: try bookmarking.bookmark(for: target), displayName: suggestedName,
                            addedAt: now(), isOwnedCopy: true)
        items.insert(item, at: 0)
        persist()
        return item
    }

    public func remove(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if item.isOwnedCopy {
            let folder = filesDir.appendingPathComponent(id.uuidString)
            if let file = bookmarking.resolve(item.bookmark) { try? discard(file) }
            try? FileManager.default.removeItem(at: folder) // now-empty holder folder
        }
        items.removeAll { $0.id == id }
        persist()
    }

    public func url(for id: UUID) -> URL? {
        items.first { $0.id == id }.flatMap { bookmarking.resolve($0.bookmark) }
    }

    public func pruneMissing() {
        let before = items.count
        items.removeAll { item in
            guard let u = bookmarking.resolve(item.bookmark) else { return true }
            return !FileManager.default.fileExists(atPath: u.path)
        }
        if items.count != before { persist() }
    }

    private var filesDir: URL { directory.appendingPathComponent("Files", isDirectory: true) }

    private func ownedFolder(_ id: UUID) throws -> URL {
        let dir = filesDir.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func persist() { try? store.save(items) }
}
