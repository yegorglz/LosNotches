import Testing
@testable import NookCore

@Test func normalizedScale() {
    #expect(AudioLevel.normalized(rms: 0) == 0)
    #expect(AudioLevel.normalized(rms: 1) == 1)
    #expect(abs(AudioLevel.normalized(rms: 0.0316227766) - 0.4) < 0.001) // −30 dBFS
    #expect(AudioLevel.normalized(rms: 0.0001) == 0)                    // −80 dBFS clamps
}
@Test func rmsOfSquareWave() {
    let s: [Float] = [0.5, -0.5, 0.5, -0.5]
    #expect(s.withUnsafeBufferPointer { AudioLevel.rms($0) } == 0.5)
}
@Test func attackFasterThanRelease() {
    var l = AudioLevel()
    l.ingest(rms: 1)
    let up = l.value
    l.ingest(rms: 0)
    #expect(up > 0.5 && l.value > up * 0.8) // rises quickly, falls slowly
}
