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
    public static func isFullscreen(windows: [WindowInfo], screenCG: CGRect, frontmostPID: Int32?,
                                    ignoredOwners: Set<String> = ["Dock", "Window Server", "LosNotches"]) -> Bool {
        guard let frontmostPID else { return false }
        let close = { (a: CGFloat, b: CGFloat) in abs(a - b) <= 1 }
        return windows.contains { w in
            w.layer == 0 && w.ownerPID == frontmostPID && !ignoredOwners.contains(w.ownerName)
                && close(w.bounds.minX, screenCG.minX) && close(w.bounds.minY, screenCG.minY)
                && close(w.bounds.maxX, screenCG.maxX) && close(w.bounds.maxY, screenCG.maxY)
        }
    }
}
