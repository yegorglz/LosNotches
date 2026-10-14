import Foundation
import Testing
@testable import NookCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)
private let s = LiveActivitiesSettings()

@Test func higherPriorityWins() {
    var q = LiveActivityQueue()
    q.upsert(.init(id: "media", kind: .media))
    q.upsert(.init(id: "hud", kind: .hud))
    #expect(q.current(now: t0, isFullscreen: false, settings: s)?.id == "hud")
}
@Test func expiredTransientFallsBackToMedia() {
    var q = LiveActivityQueue()
    q.upsert(.init(id: "media", kind: .media))
    q.upsert(.init(id: "hud", kind: .hud, expiresAt: t0 - 1))
    #expect(q.current(now: t0, isFullscreen: false, settings: s)?.id == "media")
}
@Test func disabledKindHidden() {
    var q = LiveActivityQueue(); q.upsert(.init(id: "media", kind: .media))
    var st = s; st.enabledKinds.remove(.media)
    #expect(q.current(now: t0, isFullscreen: false, settings: st) == nil)
}
@Test func globallyDisabledReturnsNil() {
    var q = LiveActivityQueue(); q.upsert(.init(id: "hud", kind: .hud))
    var st = s; st.enabled = false
    #expect(q.current(now: t0, isFullscreen: false, settings: st) == nil)
}
@Test func fullscreenFiltersKinds() {
    var q = LiveActivityQueue(); q.upsert(.init(id: "media", kind: .media))
    #expect(q.current(now: t0, isFullscreen: true, settings: s) == nil)
    q.upsert(.init(id: "timer", kind: .timer))
    #expect(q.current(now: t0, isFullscreen: true, settings: s)?.id == "timer")
}
@Test func dismissedHiddenUntilRevisionChanges() {
    var q = LiveActivityQueue(); q.upsert(.init(id: "media", kind: .media, revision: 1))
    q.dismiss(id: "media")
    #expect(q.current(now: t0, isFullscreen: false, settings: s) == nil)
    q.upsert(.init(id: "media", kind: .media, revision: 2))
    #expect(q.current(now: t0, isFullscreen: false, settings: s)?.revision == 2)
}
@Test func dismissedStaysHiddenWithoutAutoReturn() {
    var st = s; st.unhideAutomatically = false
    var q = LiveActivityQueue(); q.upsert(.init(id: "media", kind: .media, revision: 1))
    q.dismiss(id: "media")
    q.upsert(.init(id: "media", kind: .media, revision: 2))
    #expect(q.current(now: t0, isFullscreen: false, settings: st) == nil)
    q.remove(id: "media"); q.upsert(.init(id: "media", kind: .media, revision: 3))
    #expect(q.current(now: t0, isFullscreen: false, settings: st) != nil)
}
@Test func tieBreaksByMostRecentUpsert() {
    var q = LiveActivityQueue()
    q.upsert(.init(id: "a", kind: .timer)); q.upsert(.init(id: "b", kind: .timer))
    #expect(q.current(now: t0, isFullscreen: false, settings: s)?.id == "b")
}
@Test func purgeRemovesExpired() {
    var q = LiveActivityQueue(); q.upsert(.init(id: "hud", kind: .hud, expiresAt: t0))
    q.purgeExpired(now: t0)
    #expect(q.all.isEmpty)
}
