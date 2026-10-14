import AppKit
import NookCore

extension NSScreen {
    var displayID: UInt32 { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
}

extension ScreenMetrics {
    init(_ s: NSScreen) {
        self.init(displayID: s.displayID, frame: s.frame, visibleFrame: s.visibleFrame, safeAreaTop: s.safeAreaInsets.top,
                  auxiliaryLeftWidth: s.auxiliaryTopLeftArea?.width, auxiliaryRightWidth: s.auxiliaryTopRightArea?.width)
    }
}

/// Borderless, non-activating panel above the menu bar on every Space.
final class NotchPanel: NSPanel {
    var allowsKey = false
    var onScroll: ((NSEvent) -> Void)?

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { allowsKey }
    /// The panel sits over the menu bar on purpose; never let AppKit nudge it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel { onScroll?(event) }
        super.sendEvent(event)
    }
}

/// Hosting view that takes the first click (no "activate first" click) and acts as the file-drop destination.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    weak var model: NotchViewModel?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = [] // content must never resize/move the panel
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        model?.send(.dragEntered)
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let model else { return [] }
        let p = convert(sender.draggingLocation, from: nil)
        model.updateDropHover(localPoint: CGPoint(x: p.x, y: bounds.height - p.y))
        return NSEvent.modifierFlags.contains(.option) ? .move : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        model?.hoveredDropTarget = nil
        model?.send(.dragExited)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let handled = model?.handleDrop(urls) ?? false
        model?.send(.dragExited)
        return handled
    }
}

import SwiftUI
