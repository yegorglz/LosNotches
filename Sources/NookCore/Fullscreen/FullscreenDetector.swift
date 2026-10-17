import CoreGraphics

public struct WindowInfo: Equatable, Sendable {
    public var ownerPID: Int32
    public var ownerName: String
    public var layer: Int
    /// Quartz global coordinates (top-left origin).
    public var bounds: CGRect
    public init(ownerPID: Int32, ownerName: String, layer: Int, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.layer = layer
        self.bounds = bounds
    }
}

public enum FullscreenDetector {
    /// `safeAreaTop`: on notched displays fullscreen apps fill only the area below the notch, so that size counts too.
    public static func isFullscreen(windows: [WindowInfo], screenCG: CGRect, safeAreaTop: CGFloat = 0, frontmostPID: Int32?,
                                    ignoredOwners: Set<String> = ["Dock", "Window Server", "LosNotches"]) -> Bool {
        guard let frontmostPID else { return false }
        let close = { (a: CGFloat, b: CGFloat) in abs(a - b) <= 0.5 } // menu bar is 1 pt below the notch: a maximized window must not match
        let belowNotch = CGRect(x: screenCG.minX, y: screenCG.minY + safeAreaTop, width: screenCG.width, height: screenCG.height - safeAreaTop)
        let matches = { (b: CGRect, s: CGRect) in
            close(b.minX, s.minX) && close(b.minY, s.minY) && close(b.maxX, s.maxX) && close(b.maxY, s.maxY)
        }
        return windows.contains { w in
            w.layer == 0 && w.ownerPID == frontmostPID && !ignoredOwners.contains(w.ownerName)
                && (matches(w.bounds, screenCG) || matches(w.bounds, belowNotch))
        }
    }
}

/// Reads `CGSCopyManagedDisplaySpaces` output: which displays are currently showing a fullscreen Space (type 4).
public enum FullscreenSpaces {
    /// Returns display UUID strings in a fullscreen Space; `"Main"` means all displays share one set of Spaces.
    public static func displays(from managed: [[String: Any]]) -> Set<String> {
        Set(managed.compactMap { d in
            guard let id = d["Display Identifier"] as? String,
                  (d["Current Space"] as? [String: Any])?["type"] as? Int == 4 else { return nil }
            return id
        })
    }
}
