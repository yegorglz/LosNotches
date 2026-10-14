import Testing
@testable import NookCore

@Test func accumulatorEmitsDownOnceAfterThreshold() {
    var a = ScrollGestureAccumulator()
    #expect(a.ingest(fingerDX: 0, fingerDY: 20, phase: .began) == nil)
    #expect(a.ingest(fingerDX: 0, fingerDY: 15, phase: .changed) == .down)
    #expect(a.ingest(fingerDX: 0, fingerDY: 40, phase: .changed) == nil)
}
@Test func accumulatorIgnoresDiagonal() {
    var a = ScrollGestureAccumulator()
    #expect(a.ingest(fingerDX: 25, fingerDY: 25, phase: .began) == nil)
    #expect(a.ingest(fingerDX: 25, fingerDY: 25, phase: .changed) == nil)
}
@Test func accumulatorIgnoresMomentum() {
    var a = ScrollGestureAccumulator()
    #expect(a.ingest(fingerDX: 0, fingerDY: 100, phase: .momentum) == nil)
}
@Test func accumulatorResetsAfterEnded() {
    var a = ScrollGestureAccumulator()
    #expect(a.ingest(fingerDX: 0, fingerDY: -40, phase: .began) == .up)
    _ = a.ingest(fingerDX: 0, fingerDY: 0, phase: .ended)
    #expect(a.ingest(fingerDX: 0, fingerDY: -40, phase: .began) == .up)
}
@Test func accumulatorRight() {
    var a = ScrollGestureAccumulator()
    #expect(a.ingest(fingerDX: 35, fingerDY: 2, phase: .began) == .right)
}
