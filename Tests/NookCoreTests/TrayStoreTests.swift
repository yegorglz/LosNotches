import Foundation
import Testing
@testable import NookCore

private func file(_ dir: URL, _ name: String, _ text: String = "hi") throws -> URL {
    let u = dir.appendingPathComponent(name); try Data(text.utf8).write(to: u); return u
}

@Test func addPersistsAcrossInstances() throws {
    let root = tempDir(), src = tempDir()
    try TrayStore(directory: root).add([try file(src, "a.txt")], move: false)
    #expect(TrayStore(directory: root).items.map(\.displayName) == ["a.txt"])
}
@Test func moveRelocatesFileIntoTray() throws {
    let root = tempDir(), src = tempDir(), f = try file(src, "a.txt")
    let store = TrayStore(directory: root)
    let item = try store.add([f], move: true)[0]
    #expect(!FileManager.default.fileExists(atPath: f.path))
    #expect(store.url(for: item.id)?.path.contains("/Files/") == true && item.isOwnedCopy)
}
@Test func removeOwnedCopyDeletesFile() throws {
    var discarded: [String] = []
    let root = tempDir(), store = TrayStore(directory: root, discard: { discarded.append($0.lastPathComponent); try FileManager.default.removeItem(at: $0) })
    let item = try store.add([try file(tempDir(), "a.txt")], move: true)[0]
    let u = store.url(for: item.id)!
    store.remove(id: item.id)
    #expect(!FileManager.default.fileExists(atPath: u.path) && store.items.isEmpty)
    #expect(discarded == ["a.txt"])
}

struct FailingBookmarks: FileBookmarking {
    struct Boom: Error {}
    func bookmark(for url: URL) throws -> Data { throw Boom() }
    func resolve(_ data: Data) -> URL? { nil }
}
@Test func failedBookmarkAfterMoveRestoresFile() throws {
    let f = try file(tempDir(), "a.txt"), store = TrayStore(directory: tempDir(), bookmarking: FailingBookmarks())
    #expect(throws: FailingBookmarks.Boom.self) { try store.add([f], move: true) }
    #expect(FileManager.default.fileExists(atPath: f.path))
}
@Test func partialFailureKeepsEarlierItemsPersisted() throws {
    let root = tempDir(), src = tempDir(), good = try file(src, "a.txt")
    let missing = src.appendingPathComponent("gone.txt")
    #expect(throws: (any Error).self) { try TrayStore(directory: root).add([good, missing], move: true) }
    #expect(TrayStore(directory: root).items.map(\.displayName) == ["a.txt"])
}
@Test func removeReferenceKeepsOriginal() throws {
    let f = try file(tempDir(), "a.txt"), store = TrayStore(directory: tempDir())
    store.remove(id: try store.add([f], move: false)[0].id)
    #expect(FileManager.default.fileExists(atPath: f.path))
}
@Test func missingFilePrunedOnLoad() throws {
    let root = tempDir(), f = try file(tempDir(), "a.txt")
    try TrayStore(directory: root).add([f], move: false)
    try FileManager.default.removeItem(at: f)
    #expect(TrayStore(directory: root).items.isEmpty)
}
@Test func renamedFileStillResolves() throws {
    let src = tempDir(), f = try file(src, "a.txt"), store = TrayStore(directory: tempDir())
    let item = try store.add([f], move: false)[0]
    let renamed = src.appendingPathComponent("b.txt")
    try FileManager.default.moveItem(at: f, to: renamed)
    #expect(store.url(for: item.id)?.lastPathComponent == "b.txt")
}
@Test func duplicateAddBumpsToFront() throws {
    let src = tempDir(), a = try file(src, "a.txt"), b = try file(src, "b.txt"), store = TrayStore(directory: tempDir())
    try store.add([a], move: false); try store.add([b], move: false); try store.add([a], move: false)
    #expect(store.items.map(\.displayName) == ["a.txt", "b.txt"])
}
@Test func pasteDataCreatesOwnedFile() throws {
    let store = TrayStore(directory: tempDir())
    let item = try store.addData(Data("x".utf8), suggestedName: "Pasted.txt")
    #expect(item.isOwnedCopy && (try? String(contentsOf: store.url(for: item.id)!, encoding: .utf8)) == "x")
}
