import CoreGraphics

/// One display, in AppKit coordinates (bottom-left origin).
public struct ScreenMetrics: Equatable, Sendable {
    public var displayID: UInt32
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var safeAreaTop: CGFloat
    public var auxiliaryLeftWidth: CGFloat?
    public var auxiliaryRightWidth: CGFloat?

    public init(displayID: UInt32, frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat,
                auxiliaryLeftWidth: CGFloat?, auxiliaryRightWidth: CGFloat?) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryLeftWidth = auxiliaryLeftWidth
        self.auxiliaryRightWidth = auxiliaryRightWidth
    }
}

public enum NotchGeometry {
    public static let handleHitWidth: CGFloat = 180
    public static let handleVisualSize = CGSize(width: 120, height: 5)
    public static let openSize = CGSize(width: 792, height: 190)
    public static let activityWingWidth: CGFloat = 72
    public static let peekHeight: CGFloat = 28
    public static let shadowPadding: CGFloat = 20

    public static func hasNotch(_ m: ScreenMetrics) -> Bool {
        m.safeAreaTop > 0 && m.auxiliaryLeftWidth != nil && m.auxiliaryRightWidth != nil
    }

    public static func menuBarHeight(_ m: ScreenMetrics) -> CGFloat {
        max(24, m.frame.maxY - m.visibleFrame.maxY)
    }

    /// `plainHeight` overrides the closed height on screens without a notch (nil = menu bar height).
    public static func closedRect(_ m: ScreenMetrics, fineTune: CGSize, plainHeight: CGFloat? = nil) -> CGRect {
        if hasNotch(m), let left = m.auxiliaryLeftWidth, let right = m.auxiliaryRightWidth {
            let width = m.frame.width - left - right + fineTune.width
            let height = m.safeAreaTop + fineTune.height
            return CGRect(x: m.frame.minX + left - fineTune.width / 2, y: m.frame.maxY - height, width: width, height: height)
        }
        let height = plainHeight ?? menuBarHeight(m)
        return CGRect(x: m.frame.midX - handleHitWidth / 2, y: m.frame.maxY - height, width: handleHitWidth, height: height)
    }

    public static func openRect(_ m: ScreenMetrics, size: CGSize = openSize) -> CGRect {
        let midX = closedRect(m, fineTune: .zero).midX
        let width = min(size.width, m.frame.width)
        var x = midX - width / 2
        x = min(max(x, m.frame.minX), m.frame.maxX - width)
        return CGRect(x: x, y: m.frame.maxY - size.height, width: width, height: size.height)
    }

    public static func windowFrame(_ m: ScreenMetrics) -> CGRect {
        let closed = closedRect(m, fineTune: .zero).insetBy(dx: -activityWingWidth, dy: 0)
        var union = openRect(m).union(closed)
        union.origin.y -= shadowPadding
        union.size.height += shadowPadding
        return union
    }

    /// Screen rect → SwiftUI local coordinates (top-left origin) inside a window frame.
    public static func localRect(_ r: CGRect, inWindow w: CGRect) -> CGRect {
        CGRect(x: r.minX - w.minX, y: w.maxY - r.maxY, width: r.width, height: r.height)
    }

    /// AppKit global rect → Quartz global rect (top-left origin of the primary display).
    public static func cgRect(fromAppKit r: CGRect, primaryScreenHeight h: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }
}
