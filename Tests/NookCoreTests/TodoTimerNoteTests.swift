import Foundation
import Testing
@testable import NookCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)

@Test func addTrimsAndRejectsEmpty() {
    var l = TodoList()
    #expect(l.add(title: "  ", now: t0) == nil)
    #expect(l.add(title: " milk ", now: t0)?.title == "milk")
}
@Test func visibleOrderStarredThenUnstarredThenCompleted() {
    var l = TodoList()
    let a = l.add(title: "a", now: t0)!, b = l.add(title: "b", now: t0 + 1)!, c = l.add(title: "c", now: t0 + 2)!
    l.toggleStar(id: b.id)
    l.toggleComplete(id: a.id, now: t0 + 3)
    #expect(l.visible().map(\.title) == ["b", "c", "a"])
    _ = c
}
@Test func toggleCompleteSetsAndClearsCompletedAt() {
    var l = TodoList(); let a = l.add(title: "a", now: t0)!
    l.toggleComplete(id: a.id, now: t0); #expect(l.items[0].completedAt == t0)
    l.toggleComplete(id: a.id, now: t0); #expect(l.items[0].completedAt == nil)
}
@Test func archiveOnlyCompletedOlderThanWindow() {
    var l = TodoList()
    let old = l.add(title: "old", now: t0)!, recent = l.add(title: "recent", now: t0)!, open = l.add(title: "open", now: t0)!
    l.toggleComplete(id: old.id, now: t0)
    l.toggleComplete(id: recent.id, now: t0 + 24 * 3600)
    l.archiveCompleted(now: t0 + 25 * 3600)
    #expect(l.visible().map(\.title) == ["open", "recent"])
    _ = open
}
@Test func deleteRemoves() { var l = TodoList(); let a = l.add(title: "a", now: t0)!; l.delete(id: a.id); #expect(l.items.isEmpty) }
@Test func todoCodableRoundTrip() throws {
    var l = TodoList(); l.add(title: "a", now: t0)
    #expect(try JSONDecoder().decode(TodoList.self, from: JSONEncoder().encode(l)) == l)
}

@Test func startRejectsZero() { var b = TimerBook(); #expect(b.start(duration: 0, label: "", now: t0) == nil) }
@Test func remainingCountsDown() { var b = TimerBook(); let e = b.start(duration: 60, label: "", now: t0)!; #expect(b.remaining(id: e.id, now: t0 + 15) == 45) }
@Test func pauseFreezesResumeContinues() {
    var b = TimerBook(); let e = b.start(duration: 60, label: "", now: t0)!
    b.pause(id: e.id, now: t0 + 10)
    #expect(b.remaining(id: e.id, now: t0 + 100) == 50)
    b.resume(id: e.id, now: t0 + 100)
    #expect(b.remaining(id: e.id, now: t0 + 110) == 40)
}
@Test func restartResetsToDuration() {
    var b = TimerBook(); let e = b.start(duration: 60, label: "", now: t0)!
    b.restart(id: e.id, now: t0 + 50)
    #expect(b.remaining(id: e.id, now: t0 + 50) == 60)
}
@Test func collectFinishedMarksAndReturnsOnce() {
    var b = TimerBook(); b.start(duration: 10, label: "x", now: t0)
    #expect(b.collectFinished(now: t0 + 11).count == 1)
    #expect(b.collectFinished(now: t0 + 12).isEmpty)
    #expect(b.entries[0].state == .finished)
}
@Test func survivesRestartViaCodable() throws {
    var b = TimerBook(); let e = b.start(duration: 300, label: "x", now: t0)!
    var d = try JSONDecoder().decode(TimerBook.self, from: JSONEncoder().encode(b))
    #expect(d.remaining(id: e.id, now: t0 + 100) == 200)
    #expect(d.collectFinished(now: t0 + 301).count == 1)
}
@Test func wheelRoundTrip() {
    #expect(TimerWheel.seconds(h: 1, m: 2, s: 3) == 3723)
    #expect(TimerWheel.components(3723) == (1, 2, 3))
}
@Test func durationText() {
    #expect(DurationText.format(245) == "4:05")
    #expect(DurationText.format(3723) == "1:02:03")
    #expect(DurationText.format(0.2) == "0:01")
    #expect(DurationText.format(-5) == "0:00")
}
@Test func displayedFallsBackToPaused() {
    var b = TimerBook(); let e = b.start(duration: 60, label: "x", now: t0)!
    b.pause(id: e.id, now: t0 + 5)
    #expect(b.soonestRunning(now: t0 + 5) == nil && b.displayed(now: t0 + 5)?.id == e.id)
}
@Test func soonestRunningPicksEarliestEnd() {
    var b = TimerBook(); b.start(duration: 100, label: "long", now: t0); b.start(duration: 10, label: "short", now: t0)
    #expect(b.soonestRunning(now: t0)?.label == "short")
}

@Test func titleFromFirstLine() {
    var b = NoteBook(); let n = b.create(now: t0)
    b.update(id: n.id, rtf: Data(), plainText: "\n  Groceries \nmilk", now: t0)
    #expect(b.notes[0].title == "Groceries")
}
@Test func titleFallback() { var b = NoteBook(); #expect(b.create(now: t0).title == "New Note") }
@Test func titleTruncatedTo40() {
    var b = NoteBook(); let n = b.create(now: t0)
    b.update(id: n.id, rtf: Data(), plainText: String(repeating: "x", count: 60), now: t0)
    #expect(b.notes[0].title.count == 40)
}
@Test func updateBumpsUpdatedAtAndSorts() {
    var b = NoteBook(); let a = b.create(now: t0); _ = b.create(now: t0 + 1)
    b.update(id: a.id, rtf: Data(), plainText: "a", now: t0 + 5)
    #expect(b.sorted().first?.id == a.id)
}
@Test func noteDeleteRemoves() { var b = NoteBook(); let a = b.create(now: t0); b.delete(id: a.id); #expect(b.notes.isEmpty) }
@Test func noteCodableRoundTrip() throws {
    var b = NoteBook(); b.create(now: t0)
    #expect(try JSONDecoder().decode(NoteBook.self, from: JSONEncoder().encode(b)) == b)
}
@Test func debouncerFlushSavesLatestOnce() {
    var saved: [String] = []
    let s = DebouncedSaver<String>(delay: 10) { saved.append($0) }
    s.submit("a"); s.submit("b"); s.submit("c")
    s.flush(); s.flush()
    #expect(saved == ["c"])
}
@Test func debouncerFiresAfterDelay() async throws {
    let box = Box()
    let s = DebouncedSaver<String>(delay: 0.05, queue: DispatchQueue(label: "t")) { box.set($0) }
    s.submit("x")
    try await Task.sleep(nanoseconds: 300_000_000)
    #expect(box.get() == ["x"])
}
final class Box: @unchecked Sendable {
    private var v: [String] = []; private let l = NSLock()
    func set(_ s: String) { l.lock(); v.append(s); l.unlock() }
    func get() -> [String] { l.lock(); defer { l.unlock() }; return v }
}
