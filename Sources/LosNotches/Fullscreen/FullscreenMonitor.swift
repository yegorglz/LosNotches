import AppKit
import NookCore

/// Detects fullscreen apps per display from window bounds (no Screen Recording permission needed).
@MainActor
final class FullscreenMonitor {
    var onChange: ((UInt32, Bool) -> Void)?
    private var state: [UInt32: Bool] = [:]
    private var timer: Timer?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.evaluate() } }
        evaluate()
    }

    private func evaluate() {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let windows = raw.compactMap { d -> WindowInfo? in
            guard let pid = d[kCGWindowOwnerPID as String] as? Int32, let layer = d[kCGWindowLayer as String] as? Int,
                  let b = d[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: b) else { return nil }
            return WindowInfo(ownerPID: pid, ownerName: d[kCGWindowOwnerName as String] as? String ?? "", layer: layer, bounds: rect)
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let cg = NotchGeometry.cgRect(fromAppKit: screen.frame, primaryScreenHeight: primaryHeight)
            let fs = FullscreenDetector.isFullscreen(windows: windows, screenCG: cg, frontmostPID: front)
            if state[screen.displayID] != fs {
                state[screen.displayID] = fs
                onChange?(screen.displayID, fs)
            }
        }
    }
}
