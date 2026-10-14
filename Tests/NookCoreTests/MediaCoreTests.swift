import CoreGraphics
import Foundation
import Testing
@testable import NookCore

private let full = #"{"type":"data","diff":false,"payload":{"title":"Song","artist":"A","album":"L","duration":200,"elapsedTime":10,"playing":true,"bundleIdentifier":"com.spotify.client","timestamp":"2026-10-14T18:00:00Z"}}"#

@Test func fullPayloadDecodes() throws {
    var d = AdapterStreamDecoder()
    let n = try #require(try d.ingest(line: full))
    #expect(n.title == "Song" && n.artist == "A" && n.duration == 200 && n.elapsedAtTimestamp == 10)
    #expect(n.isPlaying && n.bundleID == "com.spotify.client")
    #expect(n.timestamp == ISO8601DateFormatter().date(from: "2026-10-14T18:00:00Z"))
}
@Test func diffMergesAndNullRemoves() throws {
    var d = AdapterStreamDecoder()
    _ = try d.ingest(line: full)
    let n = try #require(try d.ingest(line: #"{"type":"data","diff":true,"payload":{"album":null,"elapsedTime":20}}"#))
    #expect(n.album == "" && n.elapsedAtTimestamp == 20 && n.title == "Song")
}
@Test func emptyPayloadMeansNothingPlaying() throws {
    var d = AdapterStreamDecoder()
    _ = try d.ingest(line: full)
    #expect(try d.ingest(line: #"{"type":"data","diff":false,"payload":{}}"#) == nil)
}
@Test func malformedThrowsAndKeepsState() throws {
    var d = AdapterStreamDecoder()
    _ = try d.ingest(line: full)
    #expect(throws: AdapterDecodeError.self) { try d.ingest(line: "{oops") }
    let n = try d.ingest(line: #"{"type":"data","diff":true,"payload":{"artist":"B"}}"#)
    #expect(n?.title == "Song" && n?.artist == "B")
}
@Test func parentBundlePreferred() throws {
    var d = AdapterStreamDecoder()
    let n = try d.ingest(line: #"{"type":"data","diff":false,"payload":{"title":"V","parentApplicationBundleIdentifier":"com.google.Chrome","bundleIdentifier":"com.google.Chrome.helper"}}"#)
    #expect(n?.bundleID == "com.google.Chrome")
}
private let t0 = Date(timeIntervalSince1970: 1000)
@Test func elapsedAdvancesWhilePlaying() { #expect(NowPlaying(title: "x", duration: 100, elapsedAtTimestamp: 10, timestamp: t0).elapsed(at: t0 + 5) == 15) }
@Test func elapsedFrozenWhenPaused() {
    #expect(NowPlaying(title: "x", duration: 100, elapsedAtTimestamp: 10, timestamp: t0, playbackRate: 0, isPlaying: false).elapsed(at: t0 + 5) == 10)
}
@Test func elapsedClampedToDuration() { #expect(NowPlaying(title: "x", duration: 12, elapsedAtTimestamp: 10, timestamp: t0).elapsed(at: t0 + 100) == 12) }
@Test func lineBufferSplitsAcrossChunks() {
    var b = LineBuffer()
    #expect(b.append(Data("ab".utf8)) == [])
    #expect(b.append(Data("c\nde\n".utf8)) == ["abc", "de"])
}
@Test func lineBufferHandlesHugeLine() {
    var b = LineBuffer()
    let big = Data(repeating: 0x41, count: 2_000_000) + Data([0x0A])
    var out: [String] = []
    for start in stride(from: 0, to: big.count, by: 65_536) {
        out += b.append(big.subdata(in: start..<min(start + 65_536, big.count)))
    }
    #expect(out.count == 1 && out[0].count == 2_000_000)
}
@Test func appleScriptParsesPlaying() {
    let n = AppleScriptNowPlayingParser.parse("playing\u{1F}T\u{1F}A\u{1F}L\u{1F}180\u{1F}42", bundleID: "com.apple.Music", now: t0)
    #expect(n?.isPlaying == true && n?.duration == 180 && n?.elapsedAtTimestamp == 42 && n?.title == "T")
}
@Test func appleScriptNotRunningNil() { #expect(AppleScriptNowPlayingParser.parse("NOT_RUNNING", bundleID: "x", now: t0) == nil) }
@Test func appleScriptWrongFieldCountNil() { #expect(AppleScriptNowPlayingParser.parse("playing\u{1F}T", bundleID: "x", now: t0) == nil) }
@Test func selectorPrefersChosenAppEvenPaused() {
    let music = NowPlaying(title: "m", isPlaying: false)
    let s = MediaSourceSnapshot(system: NowPlaying(title: "sys"), appleMusic: music)
    #expect(MediaSourceSelector.select(s, preference: .appleMusic) == music)
}
@Test func selectorFallsBackToSystem() {
    let s = MediaSourceSnapshot(system: NowPlaying(title: "sys"))
    #expect(MediaSourceSelector.select(s, preference: .spotify)?.title == "sys")
}
@Test func selectorPicksPlayingAppWhenNoSystem() {
    let s = MediaSourceSnapshot(appleMusic: NowPlaying(title: "m", isPlaying: false), spotify: NowPlaying(title: "s"))
    #expect(MediaSourceSelector.select(s, preference: .automatic)?.title == "s")
}
@Test func backoffSequence() {
    var b = RestartBackoff()
    #expect((0..<7).map { _ in b.nextDelay() } == [1, 2, 4, 8, 16, 30, 30])
    b.reset()
    #expect(b.nextDelay() == 1)
}
@Test func gestureMapDefaultAndInverted() {
    #expect(MediaGestureMap.command(for: .right, inverted: false) == .next)
    #expect(MediaGestureMap.command(for: .left, inverted: false) == .previous)
    #expect(MediaGestureMap.command(for: .left, inverted: true) == .next)
    #expect(MediaGestureMap.command(for: .up, inverted: false) == nil)
}
@Test func artworkTintOfSolidRed() throws {
    var px: [UInt8] = Array(repeating: [255, 0, 0, 255], count: 4).flatMap { $0 }
    let ctx = CGContext(data: &px, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let c = try #require(ArtworkTint.averageColor(of: ctx.makeImage()!))
    #expect(abs(c.r - 1) < 0.02 && c.g < 0.02 && c.b < 0.02)
}
