import Testing
@testable import NookCore

@Test func decodesVolumeUpKeyDown() { #expect(MediaKeyEvent.decode(subtype: 8, data1: (0 << 16) | 0x0A00) == .init(key: .soundUp, isDown: true, isRepeat: false)) }
@Test func decodesKeyUp() { #expect(MediaKeyEvent.decode(subtype: 8, data1: (1 << 16) | 0x0B00) == .init(key: .soundDown, isDown: false, isRepeat: false)) }
@Test func decodesRepeat() { #expect(MediaKeyEvent.decode(subtype: 8, data1: (2 << 16) | 0x0A01) == .init(key: .brightnessUp, isDown: true, isRepeat: true)) }
@Test func wrongSubtypeNil() { #expect(MediaKeyEvent.decode(subtype: 7, data1: 0x0A00) == nil) }
@Test func unknownKeyNil() { #expect(MediaKeyEvent.decode(subtype: 8, data1: (4 << 16) | 0x0A00) == nil) }
@Test func stepUp() { #expect(LevelStep.apply(current: 0.5, up: true, fine: false) == 0.5625) }
@Test func fineStep() { #expect(LevelStep.apply(current: 0.5, up: true, fine: true) == 0.515625) }
@Test func snapsToGrid() { #expect(LevelStep.apply(current: 0.51, up: true, fine: false) == 0.5625) }
@Test func clamps() {
    #expect(LevelStep.apply(current: 1, up: true, fine: false) == 1)
    #expect(LevelStep.apply(current: 0, up: false, fine: false) == 0)
}

final class FakeRunner: ProcessRunning {
    var calls: [[String]] = []
    func run(_ path: String, _ args: [String]) { calls.append([path] + args) }
}
@Test func suspendIssuesStopOnce() {
    let r = FakeRunner(); let s = OSDSuppressor(runner: r)
    s.suspend(); s.suspend()
    #expect(r.calls == [["/usr/bin/killall", "-STOP", "OSDUIHelper"]])
}
@Test func restoreIssuesCont() {
    let r = FakeRunner(); let s = OSDSuppressor(runner: r)
    s.suspend(); s.restore()
    #expect(r.calls.last == ["/usr/bin/killall", "-CONT", "OSDUIHelper"] && !s.isSuspended)
}
@Test func restoreWithoutSuspendStillIssuesCont() {
    let r = FakeRunner(); OSDSuppressor(runner: r).restore()
    #expect(r.calls == [["/usr/bin/killall", "-CONT", "OSDUIHelper"]])
}
@Test func policyNeverSuspendsWithoutTap() {
    #expect(!HUDActivationPolicy.shouldSuspendOSD(replacementEnabled: true, tapActive: false))
    #expect(HUDActivationPolicy.shouldSuspendOSD(replacementEnabled: true, tapActive: true))
    #expect(!HUDActivationPolicy.shouldSuspendOSD(replacementEnabled: false, tapActive: true))
}
