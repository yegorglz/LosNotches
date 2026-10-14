import CoreGraphics

public struct WidgetFrame: Equatable, Sendable {
    public var kind: WidgetKind
    public var x: CGFloat
    public var width: CGFloat
    public init(kind: WidgetKind, x: CGFloat, width: CGFloat) {
        self.kind = kind
        self.x = x
        self.width = width
    }
}

public enum NookGridLayout {
    public static let cell: CGFloat = 56
    public static let maxCells = 12
    public static let spacing: CGFloat = 8

    public static func width(cells: Int) -> CGFloat { CGFloat(cells) * cell + CGFloat(cells - 1) * spacing }

    public static func layout(_ placements: [WidgetPlacement]) -> (frames: [WidgetFrame], hidden: [WidgetKind]) {
        var frames: [WidgetFrame] = []
        var hidden: [WidgetKind] = []
        var used = 0
        var x: CGFloat = 0
        for p in placements {
            let cells = min(max(p.widthCells, p.kind.minCells), maxCells)
            guard used + cells <= maxCells else { hidden.append(p.kind); continue }
            let w = width(cells: cells)
            frames.append(WidgetFrame(kind: p.kind, x: x, width: w))
            used += cells
            x += w + spacing
        }
        return (frames, hidden)
    }
}
