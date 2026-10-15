import AppKit

/// Global + local mouse monitors deciding when each notch is hovered, and spotting file drags heading for it.
@MainActor
final class MouseTracker {
    private unowned let manager: ScreenWindowManager
    private var monitors: [Any] = []
    private var menuOpen = false
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount

    init(manager: ScreenWindowManager) { self.manager = manager }

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.handle(e) }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.handle(e) }
            return e
        }) { monitors.append(l) }
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuOpen = true }
        }
        nc.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.menuOpen = false
                self?.update(NSEvent.mouseLocation, dragging: false)
            }
        }
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown: dragChangeCount = NSPasteboard(name: .drag).changeCount
        case .leftMouseUp:
            for m in manager.viewModels.values where m.state.isDropTarget { m.send(.dragExited) }
        default: break
        }
        update(NSEvent.mouseLocation, dragging: e.type == .leftMouseDragged)
    }

    private func update(_ p: NSPoint, dragging: Bool) {
        let pb = NSPasteboard(name: .drag)
        let fileDrag = dragging && pb.changeCount != dragChangeCount && (pb.types?.contains(where: acceptedDropTypes.contains) ?? false)
        for m in manager.viewModels.values {
            if fileDrag, !m.state.isDropTarget, m.closedScreenRect.insetBy(dx: -40, dy: -40).contains(p) {
                m.panel?.ignoresMouseEvents = false
                continue
            }
            m.pointerMoved(inside: m.interactiveScreenRect.contains(p), suppressExit: menuOpen)
        }
    }
}
