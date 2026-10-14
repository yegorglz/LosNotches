import Foundation

/// NX_KEYTYPE_* values from IOKit's ev_keymap.h.
public enum MediaKey: Int, Sendable {
    case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    case play = 16, next = 17, previous = 18, fast = 19, rewind = 20
}

public struct MediaKeyEvent: Equatable, Sendable {
    public var key: MediaKey
    public var isDown: Bool
    public var isRepeat: Bool

    public init(key: MediaKey, isDown: Bool, isRepeat: Bool) {
        self.key = key
        self.isDown = isDown
        self.isRepeat = isRepeat
    }

    /// Decodes an NSSystemDefined event (subtype 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS).
    public static func decode(subtype: Int16, data1: Int) -> MediaKeyEvent? {
        guard subtype == 8, let key = MediaKey(rawValue: (data1 & 0xFFFF_0000) >> 16) else { return nil }
        let flags = data1 & 0xFFFF
        return MediaKeyEvent(key: key, isDown: ((flags & 0xFF00) >> 8) == 0xA, isRepeat: (flags & 0x1) == 1)
    }
}

public enum LevelStep {
    public static func apply(current: Float, up: Bool, fine: Bool) -> Float {
        let steps: Float = fine ? 64 : 16
        let next = ((current * steps).rounded() + (up ? 1 : -1)) / steps
        return min(1, max(0, next))
    }
}

public protocol ProcessRunning {
    func run(_ path: String, _ args: [String])
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}
    public func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}

/// Freezes / thaws the system volume-brightness OSD process. `restore()` is always safe to call.
public final class OSDSuppressor {
    private let runner: ProcessRunning
    public private(set) var isSuspended = false

    public init(runner: ProcessRunning = SystemProcessRunner()) { self.runner = runner }

    public func suspend() {
        guard !isSuspended else { return }
        runner.run("/usr/bin/killall", ["-STOP", "OSDUIHelper"])
        isSuspended = true
    }

    public func restore() {
        runner.run("/usr/bin/killall", ["-CONT", "OSDUIHelper"])
        isSuspended = false
    }
}

public enum HUDActivationPolicy {
    /// Only hide the system OSD when our replacement can actually receive keys.
    public static func shouldSuspendOSD(replacementEnabled: Bool, tapActive: Bool) -> Bool {
        replacementEnabled && tapActive
    }
}
