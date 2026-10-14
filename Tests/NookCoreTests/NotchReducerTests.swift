import Testing
@testable import NookCore

private func reduce(_ s: NotchState, _ events: [NotchEvent], _ p: InteractionPolicy = InteractionPolicy()) -> NotchState {
    events.reduce(s) { NotchReducer.reduce($0, $1, p) }
}
private func state(_ mode: NotchMode, activity: Bool = false) -> NotchState {
    var s = NotchState(); s.mode = mode; s.hasActivity = activity; return s
}

@Test func hoverDoesNotOpenByDefault() { #expect(reduce(state(.closed), [.hoverEntered]).mode == .closed) }
@Test func hoverOpensWhenAlwaysOpenOnHover() {
    var p = InteractionPolicy(); p.alwaysOpenOnHover = true
    #expect(reduce(state(.closed), [.hoverEntered], p).mode == .open)
}
@Test func hoverExitClosesToActivityWhenActivityPresent() {
    #expect(reduce(state(.activity, activity: true), [.hoverEntered, .click, .hoverExited]).mode == .activity)
}
@Test func lockKeepsOpenOnHoverExit() { #expect(reduce(state(.closed), [.hoverEntered, .click, .toggleLock, .hoverExited]).mode == .open) }
@Test func typingKeepsOpenThenClosesWhenTypingEndsOutside() {
    let s = reduce(state(.closed), [.hoverEntered, .click, .typingChanged(true), .hoverExited])
    #expect(s.mode == .open)
    #expect(reduce(s, [.typingChanged(false)]).mode == .closed)
}
@Test func clickDisabledDoesNothing() {
    var p = InteractionPolicy(); p.clickToOpen = false
    #expect(reduce(state(.closed), [.click], p).mode == .closed)
}
@Test func swipeUpOnClosedHides_swipeDownUnhides() {
    let hidden = reduce(state(.closed), [.swipeUp])
    #expect(hidden.mode == .hidden)
    #expect(reduce(hidden, [.swipeDown]).mode == .closed)
}
@Test func verticalGesturesDisabledIgnoresSwipes() {
    var p = InteractionPolicy(); p.verticalGestures = false
    #expect(reduce(state(.closed), [.swipeDown], p).mode == .closed)
    #expect(reduce(state(.open), [.swipeUp], p).mode == .open)
}
@Test func activityUnhidesWhenAutoUnhide() { #expect(reduce(state(.hidden), [.activityChanged(present: true)]).mode == .activity) }
@Test func activityDoesNotUnhideWhenAutoUnhideOff() {
    var p = InteractionPolicy(); p.unhideAutomatically = false
    #expect(reduce(state(.hidden), [.activityChanged(present: true)], p).mode == .hidden)
}
@Test func peekOnlyFromActivity() {
    #expect(reduce(state(.closed), [.peek]).mode == .closed)
    #expect(reduce(state(.activity, activity: true), [.peek]).mode == .peek)
    #expect(reduce(state(.activity, activity: true), [.peek, .peekEnded]).mode == .activity)
}
@Test func dragOpensFromHiddenAndExitReturns() {
    let s = reduce(state(.hidden), [.dragEntered])
    #expect(s.mode == .open && s.isDropTarget)
    #expect(reduce(s, [.dragExited]).mode == .closed)
}
@Test func fullscreenClosesOpenNookWhenNotHovering() { #expect(reduce(state(.open), [.fullscreenChanged(true)]).mode == .closed) }
@Test func closeRequestedClearsLock() {
    let s = reduce(state(.closed), [.click, .toggleLock, .closeRequested])
    #expect(s.mode == .closed && !s.isLocked)
}
@Test func swipeUpOnActivityLeavesModeForAppDismissal() { #expect(reduce(state(.activity, activity: true), [.swipeUp]).mode == .activity) }
