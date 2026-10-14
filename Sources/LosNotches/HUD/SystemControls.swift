import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation

/// Default output device volume / mute through CoreAudio.
enum SystemVolume {
    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static var device: AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
        return id
    }

    static func get() -> Float? {
        guard let d = device else { return nil }
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        return AudioObjectGetPropertyData(d, &addr, 0, nil, &size, &v) == noErr ? v : nil
    }

    static func set(_ value: Float) -> Bool {
        guard let d = device else { return false }
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(d, &addr, &settable) == noErr, settable.boolValue else { return false }
        var v = Float32(value)
        return AudioObjectSetPropertyData(d, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    static func isMuted() -> Bool? {
        guard let d = device else { return nil }
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = address(kAudioDevicePropertyMute)
        return AudioObjectGetPropertyData(d, &addr, 0, nil, &size, &v) == noErr ? v != 0 : nil
    }

    static func setMuted(_ muted: Bool) -> Bool {
        guard let d = device else { return false }
        var addr = address(kAudioDevicePropertyMute)
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(d, &addr, &settable) == noErr, settable.boolValue else { return false }
        var v = UInt32(muted ? 1 : 0)
        return AudioObjectSetPropertyData(d, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr
    }

    private static var observedDevice: AudioDeviceID?
    private static var callback: (() -> Void)?
    private static let listener: AudioObjectPropertyListenerBlock = { _, _ in DispatchQueue.main.async { callback?() } }

    /// Calls back on volume / mute changes, following default-device switches.
    static func observe(_ cb: @escaping () -> Void) {
        callback = cb
        var defAddr = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defAddr, .main) { _, _ in rebind() }
        rebind()
    }

    private static func rebind() {
        if let old = observedDevice {
            var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            AudioObjectRemovePropertyListenerBlock(old, &a, .main, listener)
            var m = address(kAudioDevicePropertyMute)
            AudioObjectRemovePropertyListenerBlock(old, &m, .main, listener)
        }
        guard let d = device else { return }
        var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        AudioObjectAddPropertyListenerBlock(d, &a, .main, listener)
        var m = address(kAudioDevicePropertyMute)
        AudioObjectAddPropertyListenerBlock(d, &m, .main, listener)
        observedDevice = d
    }
}

/// Built-in display brightness through the private DisplayServices framework.
enum DisplayBrightness {
    private typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (UInt32, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getter: Getter? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: Getter.self) }
    private static let setter: Setter? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: Setter.self) }

    private static var builtIn: UInt32? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func get() -> Float? {
        guard let getter, let id = builtIn else { return nil }
        var v: Float = 0
        return getter(id, &v) == 0 ? v : nil
    }

    static func set(_ v: Float) -> Bool {
        guard let setter, let id = builtIn else { return false }
        return setter(id, v) == 0
    }
}
