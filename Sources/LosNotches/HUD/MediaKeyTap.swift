import AppKit
import NookCore

/// Session event tap for volume / brightness / mute keys. Needs Accessibility; `start()` returns false without it.
final class MediaKeyTap {
    /// Return true to swallow the event. Second argument: fine-step modifier (⌥⇧) held.
    var handler: ((MediaKeyEvent, Bool) -> Bool)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << 14) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
                                              let me = Unmanaged<MediaKeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                                              return me.handle(type: type, event: event)
                                          }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let fine = event.flags.contains(.maskAlternate) && event.flags.contains(.maskShift)
        var decoded: MediaKeyEvent?
        if type.rawValue == 14, let ns = NSEvent(cgEvent: event) {
            decoded = MediaKeyEvent.decode(subtype: ns.subtype.rawValue, data1: ns.data1)
        } else if type == .keyDown || type == .keyUp {
            // Apple keyboards' F1/F2 brightness keys arrive as plain key codes on some Macs.
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if code == 144 || code == 145 {
                decoded = MediaKeyEvent(key: code == 144 ? .brightnessUp : .brightnessDown, isDown: type == .keyDown,
                                        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            }
        }
        if let decoded, handler?(decoded, fine) == true { return nil }
        return Unmanaged.passUnretained(event)
    }
}
