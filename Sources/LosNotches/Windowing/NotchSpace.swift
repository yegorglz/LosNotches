import AppKit

/// A private SkyLight space layered above every regular Space. Windows in it don't slide with
/// Space-switch animations, so the island stays welded to the physical notch.
/// shortcut: private API (same approach as boring.notch); if Apple removes it, windows fall back to normal Spaces.
@MainActor
final class NotchSpace {
    static let shared = NotchSpace()
    private let cid = _CGSDefaultConnection()
    private let id: UInt64

    private init() {
        id = CGSSpaceCreate(cid, 1, nil) // flag must be 1, or Finder draws desktop icons into it
        CGSSpaceSetAbsoluteLevel(cid, id, Int32.max)
        CGSShowSpaces(cid, [NSNumber(value: id)] as CFArray)
    }

    func add(_ window: NSWindow) {
        CGSAddWindowsToSpaces(cid, [NSNumber(value: window.windowNumber)] as CFArray, [NSNumber(value: id)] as CFArray)
    }

    func remove(_ window: NSWindow) {
        CGSRemoveWindowsFromSpaces(cid, [NSNumber(value: window.windowNumber)] as CFArray, [NSNumber(value: id)] as CFArray)
    }
}

@_silgen_name("_CGSDefaultConnection") private func _CGSDefaultConnection() -> Int32
@_silgen_name("CGSSpaceCreate") private func CGSSpaceCreate(_ cid: Int32, _ flag: Int32, _ options: CFDictionary?) -> UInt64
@_silgen_name("CGSSpaceSetAbsoluteLevel") private func CGSSpaceSetAbsoluteLevel(_ cid: Int32, _ space: UInt64, _ level: Int32)
@_silgen_name("CGSShowSpaces") private func CGSShowSpaces(_ cid: Int32, _ spaces: CFArray)
@_silgen_name("CGSAddWindowsToSpaces") private func CGSAddWindowsToSpaces(_ cid: Int32, _ windows: CFArray, _ spaces: CFArray)
@_silgen_name("CGSRemoveWindowsFromSpaces") private func CGSRemoveWindowsFromSpaces(_ cid: Int32, _ windows: CFArray, _ spaces: CFArray)
