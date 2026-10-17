import CoreAudio
import Foundation
import NookCore

/// Loudness of what the Mac is playing, via a Core Audio process tap (macOS 14.2+, asks for
/// "System Audio Recording" once). Effects read `level` every frame; `hasSignal` is false until real audio
/// arrives (denied permission or silence), so effects can fall back to their idle animation.
final class AudioLevelMonitor: @unchecked Sendable {
    static let shared = AudioLevelMonitor()

    private let lock = NSLock()
    private var smoothed = AudioLevel()
    private var lastSignal = Date.distantPast
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "losnotches.audio-level")

    var level: Float { lock.lock(); defer { lock.unlock() }; return smoothed.value }
    var hasSignal: Bool { lock.lock(); defer { lock.unlock() }; return Date().timeIntervalSince(lastSignal) < 1.5 }
    var isRunning: Bool { procID != nil }

    func start() {
        guard procID == nil, #available(macOS 14.2, *) else { return }
        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        desc.uuid = UUID()
        desc.isPrivate = true
        desc.muteBehavior = .unmuted
        guard AudioHardwareCreateProcessTap(desc, &tapID) == noErr, let output = Self.defaultOutputUID() else { return stop() }
        let config: [String: Any] = [
            kAudioAggregateDeviceNameKey: "LosNotches Level",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: output,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: output]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        guard AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregateID) == noErr else { return stop() }
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, _, _, _ in
            self?.consume(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)))
        }
        guard status == noErr, AudioDeviceStart(aggregateID, procID) == noErr else { return stop() }
    }

    func stop() {
        if let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        if tapID != kAudioObjectUnknown, #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tapID) }
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        lock.lock(); smoothed = AudioLevel(); lastSignal = .distantPast; lock.unlock()
    }

    private func consume(_ buffers: UnsafeMutableAudioBufferListPointer) {
        var peak: Float = 0
        for b in buffers {
            guard let data = b.mData else { continue }
            let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(b.mDataByteSize) / MemoryLayout<Float>.size)
            peak = max(peak, AudioLevel.rms(samples))
        }
        lock.lock()
        smoothed.ingest(rms: peak)
        if peak > 0.0005 { lastSignal = Date() } // a denied tap delivers pure zeros
        lock.unlock()
    }

    private static func defaultOutputUID() -> String? {
        guard let device = SystemVolume.device else { return nil }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &uid) == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }
}
