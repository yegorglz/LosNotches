import Foundation
import Testing
@testable import NookCore

func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nooktest-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

struct Sample: Codable, Equatable { var n: Int; var s: String }

@Test func missingFileReturnsDefault() {
    let store = JSONFileStore(url: tempDir().appendingPathComponent("x.json")) { Sample(n: 1, s: "d") }
    #expect(store.load() == Sample(n: 1, s: "d"))
}

@Test func roundTrip() throws {
    let store = JSONFileStore(url: tempDir().appendingPathComponent("x.json")) { Sample(n: 0, s: "") }
    try store.save(Sample(n: 5, s: "five"))
    #expect(store.load() == Sample(n: 5, s: "five"))
}

@Test func corruptFileIsBackedUpAndDefaultReturned() throws {
    let dir = tempDir()
    let url = dir.appendingPathComponent("x.json")
    try Data("{not json".utf8).write(to: url)
    let store = JSONFileStore(url: url) { Sample(n: 9, s: "def") }
    #expect(store.load() == Sample(n: 9, s: "def"))
    let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    #expect(names.contains { $0.hasPrefix("x.json.corrupt-") })
}

@Test func saveCreatesParentDirectory() throws {
    let url = tempDir().appendingPathComponent("a/b/x.json")
    try JSONFileStore(url: url) { Sample(n: 0, s: "") }.save(Sample(n: 2, s: "b"))
    #expect(FileManager.default.fileExists(atPath: url.path))
}
