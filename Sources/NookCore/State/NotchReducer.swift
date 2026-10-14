import Foundation

public enum NotchMode: Equatable, Sendable { case closed, activity, peek, open, hidden }

public struct NotchState: Equatable, Sendable {
    public var mode: NotchMode = .closed
    public var isHovering = false
    public var isLocked = false
    public var isTyping = false
    public var isDropTarget = false
    public var hasActivity = false
    public var isFullscreen = false
    public var restingMode: NotchMode { hasActivity ? .activity : .closed }
    public init() {}
}

public enum NotchEvent: Equatable, Sendable {
    case hoverEntered, hoverExited, click, swipeDown, swipeUp, toggleLock
    case typingChanged(Bool)
    case activityChanged(present: Bool)
    case peek, peekEnded
    case fullscreenChanged(Bool)
    case dragEntered, dragExited, closeRequested
}

public struct InteractionPolicy: Equatable, Sendable {
    public var alwaysOpenOnHover = false
    public var clickToOpen = true
    public var preventCloseOnMouseLeave = false
    public var lockWhileTyping = true
    public var verticalGestures = true
    public var unhideAutomatically = true

    public init() {}
    public init(_ s: AppSettings) {
        alwaysOpenOnHover = s.general.alwaysOpenOnHover
        clickToOpen = s.general.clickToOpen
        preventCloseOnMouseLeave = s.general.preventCloseOnMouseLeave
        lockWhileTyping = s.general.lockWhileTyping
        verticalGestures = s.gestures.allowGestures && s.gestures.verticalOpenClose
        unhideAutomatically = s.liveActivities.unhideAutomatically
    }
}

public enum NotchReducer {
    public static func reduce(_ state: NotchState, _ event: NotchEvent, _ p: InteractionPolicy) -> NotchState {
        var s = state
        let staysOpen = s.isLocked || p.preventCloseOnMouseLeave || (s.isTyping && p.lockWhileTyping) || s.isDropTarget
        switch event {
        case .hoverEntered:
            s.isHovering = true
            if [.closed, .activity].contains(s.mode), p.alwaysOpenOnHover { s.mode = .open }
        case .hoverExited:
            s.isHovering = false
            if s.mode == .peek || (s.mode == .open && !staysOpen) { s.mode = s.restingMode }
        case .click:
            if [.closed, .activity, .peek].contains(s.mode), p.clickToOpen { s.mode = .open }
            else if s.mode == .hidden { s.mode = s.restingMode }
        case .swipeDown:
            guard p.verticalGestures else { break }
            if s.mode == .hidden { s.mode = s.restingMode }
            else if [.closed, .activity, .peek].contains(s.mode) { s.mode = .open }
        case .swipeUp:
            guard p.verticalGestures else { break }
            if s.mode == .open { s.mode = s.restingMode; s.isLocked = false }
            else if s.mode == .closed { s.mode = .hidden }
        case .toggleLock:
            if s.mode == .open { s.isLocked.toggle() }
        case .typingChanged(let typing):
            s.isTyping = typing
            let stillStays = s.isLocked || p.preventCloseOnMouseLeave || s.isDropTarget
            if !typing, s.mode == .open, !s.isHovering, !stillStays { s.mode = s.restingMode }
        case .activityChanged(let present):
            s.hasActivity = present
            if [.closed, .activity, .peek].contains(s.mode) { s.mode = s.restingMode }
            else if s.mode == .hidden, present, p.unhideAutomatically { s.mode = s.restingMode }
        case .peek:
            if s.mode == .activity { s.mode = .peek }
        case .peekEnded:
            if s.mode == .peek { s.mode = s.restingMode }
        case .fullscreenChanged(let fs):
            s.isFullscreen = fs
            if fs, s.mode == .open, !s.isHovering { s.mode = s.restingMode }
        case .dragEntered:
            s.isDropTarget = true
            s.mode = .open
        case .dragExited:
            s.isDropTarget = false
            if !s.isHovering { s.mode = s.restingMode }
        case .closeRequested:
            s.mode = s.restingMode
            s.isLocked = false
            s.isDropTarget = false
        }
        return s
    }
}
