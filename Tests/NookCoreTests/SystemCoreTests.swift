import CoreGraphics
import Testing
@testable import NookCore

private func snap(_ plugged: Bool, _ pct: Int, charged: Bool = false) -> PowerSnapshot {
    PowerSnapshot(isPluggedIn: plugged, isCharging: plugged && pct < 100, percent: pct, isCharged: charged)
}
@Test func baselineNoEvent() { var d = BatteryTransitionDetector(lowThreshold: 20); #expect(d.ingest(snap(false, 10)) == nil) }
@Test func plugAndUnplugEvents() {
    var d = BatteryTransitionDetector(lowThreshold: 20)
    _ = d.ingest(snap(false, 50))
    #expect(d.ingest(snap(true, 50)) == .pluggedIn(percent: 50))
    #expect(d.ingest(snap(false, 50)) == .unplugged(percent: 50))
}
@Test func onePercentDropIsSilent() {
    var d = BatteryTransitionDetector(lowThreshold: 20)
    _ = d.ingest(snap(false, 50))
    #expect(d.ingest(snap(false, 49)) == nil)
    #expect(d.ingest(snap(false, 48)) == nil)
}
@Test func lowFiresOnceOnCrossing() {
    var d = BatteryTransitionDetector(lowThreshold: 20)
    _ = d.ingest(snap(false, 21))
    #expect(d.ingest(snap(false, 20)) == .low(percent: 20))
    #expect(d.ingest(snap(false, 19)) == nil)
}
@Test func lowRearmsAfterRisingAboveThreshold() {
    var d = BatteryTransitionDetector(lowThreshold: 20)
    _ = d.ingest(snap(false, 21)); _ = d.ingest(snap(false, 20))
    _ = d.ingest(snap(true, 20)); _ = d.ingest(snap(true, 25)); _ = d.ingest(snap(false, 25))
    #expect(d.ingest(snap(false, 20)) == .low(percent: 20))
}
@Test func fullFiresOncePerPlugSession() {
    var d = BatteryTransitionDetector(lowThreshold: 20)
    _ = d.ingest(snap(true, 98))
    #expect(d.ingest(snap(true, 100, charged: true)) == .full)
    #expect(d.ingest(snap(true, 100, charged: true)) == nil)
    _ = d.ingest(snap(false, 100)); _ = d.ingest(snap(true, 99))
    #expect(d.ingest(snap(true, 100, charged: true)) == .full)
}
@Test func deviceKindMappings() {
    #expect(BluetoothDeviceKind.from(major: 0x04, minor: 0x06) == .headphones)
    #expect(BluetoothDeviceKind.from(major: 0x04, minor: 0x01) == .headphones)
    #expect(BluetoothDeviceKind.from(major: 0x04, minor: 0x05) == .speaker)
    #expect(BluetoothDeviceKind.from(major: 0x05, minor: 0x10) == .keyboard)
    #expect(BluetoothDeviceKind.from(major: 0x05, minor: 0x20) == .mouse)
    #expect(BluetoothDeviceKind.from(major: 0x05, minor: 0x30) == .mouse)
    #expect(BluetoothDeviceKind.from(major: 0x05, minor: 0x02) == .gamepad)
    #expect(BluetoothDeviceKind.from(major: 0x02, minor: 0x03) == .phone)
    #expect(BluetoothDeviceKind.from(major: 0x01, minor: 0) == .other)
}
@Test func parsesLines() { #expect(ShortcutsListParser.parse("A\n B \n\nA\nC") == ["A", "B", "C"]) }
@Test func emptyOutput() { #expect(ShortcutsListParser.parse("") == []) }

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
private func win(_ pid: Int32, _ b: CGRect, owner: String = "Safari", layer: Int = 0) -> WindowInfo { WindowInfo(ownerPID: pid, ownerName: owner, layer: layer, bounds: b) }
@Test func fullscreenWindowDetected() { #expect(FullscreenDetector.isFullscreen(windows: [win(5, screen)], screenCG: screen, frontmostPID: 5)) }
@Test func fullscreenBelowNotchDetected() {
    let below = CGRect(x: 0, y: 32, width: 1512, height: 950)
    #expect(FullscreenDetector.isFullscreen(windows: [win(5, below)], screenCG: screen, safeAreaTop: 32, frontmostPID: 5))
    #expect(!FullscreenDetector.isFullscreen(windows: [win(5, below)], screenCG: screen, frontmostPID: 5)) // no notch: not fullscreen
}
@Test func maximizedWindowWithHiddenDockIsNotFullscreen() {
    // Real 14" MBP: notch 32 pt, menu bar 33 pt; a maximized window starts at the menu bar.
    let maximized = CGRect(x: 0, y: 33, width: 1512, height: 949)
    #expect(!FullscreenDetector.isFullscreen(windows: [win(5, maximized)], screenCG: screen, safeAreaTop: 32, frontmostPID: 5))
}
@Test func maximizedWindowNotFullscreen() {
    #expect(!FullscreenDetector.isFullscreen(windows: [win(5, CGRect(x: 0, y: 33, width: 1512, height: 949))], screenCG: screen, frontmostPID: 5))
}
@Test func otherAppWindowIgnored() { #expect(!FullscreenDetector.isFullscreen(windows: [win(6, screen)], screenCG: screen, frontmostPID: 5)) }
@Test func toleranceAccepted() {
    #expect(FullscreenDetector.isFullscreen(windows: [win(5, CGRect(x: 0.5, y: 0, width: 1511.5, height: 982))], screenCG: screen, frontmostPID: 5))
}
@Test func dockIgnored() { #expect(!FullscreenDetector.isFullscreen(windows: [win(5, screen, owner: "Dock")], screenCG: screen, frontmostPID: 5)) }
@Test func secondaryScreenCoordinates() {
    let ext = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
    #expect(FullscreenDetector.isFullscreen(windows: [win(5, ext)], screenCG: ext, frontmostPID: 5))
    #expect(!FullscreenDetector.isFullscreen(windows: [win(5, ext)], screenCG: screen, frontmostPID: 5))
}
