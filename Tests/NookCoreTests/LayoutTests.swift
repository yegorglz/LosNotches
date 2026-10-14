import CoreGraphics
import Testing
@testable import NookCore

@Test func defaultLayoutFillsTwelveCells() {
    let r = NookGridLayout.layout(NookLayoutSettings().widgets)
    #expect(r.frames.map(\.x) == [0, 256, 512])
    #expect(r.frames.map(\.width) == [248, 248, 248])
    #expect(r.hidden.isEmpty)
}
@Test func overflowWidgetHidden() {
    let r = NookGridLayout.layout([.init(kind: .media, widthCells: 6), .init(kind: .calendar, widthCells: 4), .init(kind: .timer, widthCells: 3)])
    #expect(r.hidden == [.timer])
}
@Test func widthClampedToMin() { #expect(NookGridLayout.layout([.init(kind: .timer, widthCells: 1)]).frames[0].width == 120) }

let visible = CGRect(x: 0, y: 0, width: 1512, height: 949)
@Test func frameNilGivesCenteredDefault() { #expect(SettingsWindowFrame.sanitized(saved: nil, visible: visible) == CGRect(x: 396, y: 204.5, width: 720, height: 540)) }
@Test func frameTooSmallReset() { #expect(SettingsWindowFrame.sanitized(saved: CGRect(x: 10, y: 10, width: 100, height: 100), visible: visible).width == 720) }
@Test func frameOffscreenReset() { #expect(SettingsWindowFrame.sanitized(saved: CGRect(x: 5000, y: 10, width: 800, height: 600), visible: visible).minX == 396) }
@Test func frameValidKept() {
    let f = CGRect(x: 100, y: 100, width: 800, height: 600)
    #expect(SettingsWindowFrame.sanitized(saved: f, visible: visible) == f)
}
