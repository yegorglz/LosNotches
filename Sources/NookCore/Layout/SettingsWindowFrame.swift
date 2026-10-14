import CoreGraphics

public enum SettingsWindowFrame {
    public static let minSize = CGSize(width: 640, height: 480)
    public static let defaultSize = CGSize(width: 720, height: 540)

    /// Recovers from a missing, too-small or off-screen saved frame.
    public static func sanitized(saved: CGRect?, visible: CGRect) -> CGRect {
        let centered = CGRect(x: visible.midX - defaultSize.width / 2, y: visible.midY - defaultSize.height / 2,
                              width: defaultSize.width, height: defaultSize.height)
        guard let saved, saved.width >= minSize.width, saved.height >= minSize.height else { return centered }
        let inside = saved.intersection(visible)
        guard !inside.isNull, inside.width * inside.height >= 0.5 * saved.width * saved.height else { return centered }
        return saved
    }
}
