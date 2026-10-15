import CoreGraphics
import Testing
@testable import NookCore

let mbp = ScreenMetrics(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949), safeAreaTop: 32,
                        auxiliaryLeftWidth: 657, auxiliaryRightWidth: 657)
let ext = ScreenMetrics(displayID: 2, frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
                        visibleFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1055), safeAreaTop: 0,
                        auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil)

@Test func mbpClosedRect() { #expect(NotchGeometry.closedRect(mbp, fineTune: .zero) == CGRect(x: 657, y: 950, width: 198, height: 32)) }
@Test func fineTuneGrowsCentered() {
    #expect(NotchGeometry.closedRect(mbp, fineTune: CGSize(width: 4, height: 2)) == CGRect(x: 655, y: 948, width: 202, height: 34))
}
@Test func externalNoNotch() {
    #expect(!NotchGeometry.hasNotch(ext))
    #expect(NotchGeometry.closedRect(ext, fineTune: .zero) == CGRect(x: 2382, y: 1055, width: 180, height: 25))
}
@Test func plainScreenHeightOverride() {
    #expect(NotchGeometry.closedRect(ext, fineTune: .zero, plainHeight: 34) == CGRect(x: 2382, y: 1046, width: 180, height: 34))
    #expect(NotchGeometry.closedRect(mbp, fineTune: .zero, plainHeight: 34).height == 32) // ignored on notch screens
}
@Test func mbpOpenRect() { #expect(NotchGeometry.openRect(mbp) == CGRect(x: 360, y: 792, width: 792, height: 190)) }
@Test func openRectClampsToNarrowScreen() {
    var narrow = ext
    narrow.frame = CGRect(x: 0, y: 0, width: 600, height: 800)
    narrow.visibleFrame = CGRect(x: 0, y: 0, width: 600, height: 776)
    let r = NotchGeometry.openRect(narrow)
    #expect(r.minX == 0 && r.width == 600)
}
@Test func localRectFlipsY() {
    #expect(NotchGeometry.windowFrame(mbp) == CGRect(x: 360, y: 772, width: 792, height: 210))
    #expect(NotchGeometry.localRect(CGRect(x: 657, y: 950, width: 198, height: 32), inWindow: CGRect(x: 360, y: 772, width: 792, height: 210))
        == CGRect(x: 297, y: 0, width: 198, height: 32))
}
@Test func cgConversion() {
    #expect(NotchGeometry.cgRect(fromAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982), primaryScreenHeight: 982) == CGRect(x: 0, y: 0, width: 1512, height: 982))
    #expect(NotchGeometry.cgRect(fromAppKit: CGRect(x: 1512, y: 0, width: 1920, height: 1080), primaryScreenHeight: 982) == CGRect(x: 1512, y: -98, width: 1920, height: 1080))
}
@Test func diffAddedRemovedChanged() {
    var two = ext
    let one = ScreenMetrics(displayID: 1, frame: .zero, visibleFrame: .zero, safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil)
    var twoChanged = two
    twoChanged.frame.size.width = 2560
    var three = ext
    three.displayID = 3
    two.displayID = 2
    #expect(ScreenDiff.compute(old: [one, two], new: [twoChanged, three]) == ScreenDiff(added: [3], removed: [1], changed: [2]))
}
@Test func diffNoChange() { #expect(ScreenDiff.compute(old: [mbp, ext], new: [mbp, ext]) == ScreenDiff(added: [], removed: [], changed: [])) }
