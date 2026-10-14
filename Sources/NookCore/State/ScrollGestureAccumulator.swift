import CoreGraphics

public enum ScrollPhase: Sendable { case began, changed, ended, momentum }
public enum SwipeGesture: Equatable, Sendable { case up, down, left, right }

/// Turns trackpad scroll deltas (finger motion: +y down, +x right) into one swipe per gesture.
public struct ScrollGestureAccumulator {
    public var threshold: CGFloat = 30
    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var emitted = false

    public init(threshold: CGFloat = 30) { self.threshold = threshold }

    public mutating func ingest(fingerDX: CGFloat, fingerDY: CGFloat, phase: ScrollPhase) -> SwipeGesture? {
        switch phase {
        case .momentum: return nil
        case .ended:
            dx = 0; dy = 0; emitted = false
            return nil
        case .began, .changed:
            dx += fingerDX
            dy += fingerDY
            guard !emitted else { return nil }
            let ax = abs(dx), ay = abs(dy)
            if ay > threshold, ay > 1.5 * ax { emitted = true; return dy > 0 ? .down : .up }
            if ax > threshold, ax > 1.5 * ay { emitted = true; return dx > 0 ? .right : .left }
            return nil
        }
    }
}
