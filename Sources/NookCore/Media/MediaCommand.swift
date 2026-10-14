public enum MediaCommand: Equatable, Sendable {
    case play, pause, togglePlayPause, next, previous

    /// Command id for `mediaremote-adapter send`.
    public var adapterID: Int {
        switch self {
        case .play: 0
        case .pause: 1
        case .togglePlayPause: 2
        case .next: 4
        case .previous: 5
        }
    }
}

public enum MediaGestureMap {
    public static func command(for g: SwipeGesture, inverted: Bool) -> MediaCommand? {
        switch g {
        case .right: inverted ? .previous : .next
        case .left: inverted ? .next : .previous
        case .up, .down: nil
        }
    }
}
