import AppKit
import NookCore
import SwiftUI

enum DropTarget: Hashable { case tray, airdrop }
enum NookTab: Hashable { case nook, tray }

@MainActor
@Observable
final class NotchViewModel {
    var metrics: ScreenMetrics
    private(set) var state = NotchState()
    var hoveredDropTarget: DropTarget?
    var tab: NookTab = .nook
    var dropTargetFrames: [DropTarget: CGRect] = [:]
    @ObservationIgnored weak var panel: NotchPanel?
    @ObservationIgnored let services: AppServices
    @ObservationIgnored private var exitWork: DispatchWorkItem?
    @ObservationIgnored private var peekWork: DispatchWorkItem?
    @ObservationIgnored private var peekEndWork: DispatchWorkItem?
    @ObservationIgnored private var scroll = ScrollGestureAccumulator()

    init(metrics: ScreenMetrics, services: AppServices) {
        self.metrics = metrics
        self.services = services
    }

    var displayID: UInt32 { metrics.displayID }
    var hasNotch: Bool { NotchGeometry.hasNotch(metrics) }
    var settings: AppSettings { services.settings.settings }
    var activity: LiveActivity? { services.activities.current(for: displayID) }

    // MARK: geometry (screen coordinates)

    var windowFrame: CGRect { NotchGeometry.windowFrame(metrics) }
    var closedScreenRect: CGRect {
        NotchGeometry.closedRect(metrics, fineTune: CGSize(width: settings.general.notchWidthFineTune, height: settings.general.notchHeightFineTune),
                                 plainHeight: settings.general.nonNotchHeight > 0 ? settings.general.nonNotchHeight : nil)
    }
    var openScreenRect: CGRect { NotchGeometry.openRect(metrics) }
    var activityScreenRect: CGRect {
        var r = closedScreenRect.insetBy(dx: -NotchGeometry.activityWingWidth, dy: 0)
        if state.mode == .peek { r.origin.y -= NotchGeometry.peekHeight; r.size.height += NotchGeometry.peekHeight }
        return r
    }
    /// Fullscreen app on this display and nothing allowed to show: get out of the way entirely.
    var hiddenForFullscreen: Bool {
        state.isFullscreen && !settings.general.showInFullscreen && activity == nil && state.mode != .open
    }

    var interactiveScreenRect: CGRect {
        if hiddenForFullscreen { return .null }
        return switch state.mode {
        case .open: openScreenRect
        case .activity, .peek: activityScreenRect
        case .closed, .hidden: closedScreenRect.insetBy(dx: -8, dy: -8)
        }
    }

    /// Visible black shape, in window-local (top-left) coordinates.
    var shapeRect: CGRect {
        let screen: CGRect
        switch state.mode {
        case .open: screen = openScreenRect
        case .activity, .peek: screen = activityScreenRect
        case .closed, .hidden:
            var r = closedScreenRect
            if state.isHovering, state.mode == .closed { r = r.insetBy(dx: -4, dy: 0); r.origin.y -= 2; r.size.height += 2 }
            screen = r
        }
        return NotchGeometry.localRect(screen, inWindow: windowFrame)
    }

    // MARK: events

    func send(_ e: NotchEvent) {
        let old = state
        state = NotchReducer.reduce(state, e, InteractionPolicy(settings))
        if old.mode != state.mode { modeChanged(from: old.mode) }
        if e == .hoverEntered, state.mode == .activity, settings.liveActivities.quickPeek { schedulePeek(after: 0.3, duration: 2.5) }
    }

    private func modeChanged(from old: NotchMode) {
        panel?.allowsKey = state.mode == .open
        if old == .open {
            services.flushAll()
            endTyping()
            if let panel, panel.isKeyWindow {
                // Give keyboard focus back to the app the user was in; orderOut drops the panel from every space.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
                NotchSpace.shared.add(panel)
            }
        }
        if state.mode != .peek { peekWork?.cancel(); peekEndWork?.cancel() }
    }

    @ObservationIgnored private var lastActivityID: String?

    /// Called whenever the activity center changes; only presence / identity changes matter here.
    func syncActivity() {
        let id = activity?.id
        guard id != lastActivityID || (id != nil) != state.hasActivity else { return }
        if state.mode == .peek, id != lastActivityID { send(.peekEnded) }
        lastActivityID = id
        send(.activityChanged(present: id != nil))
    }

    func peek(seconds: TimeInterval) {
        guard state.mode == .activity else { return }
        schedulePeek(after: 0, duration: seconds)
    }

    private func schedulePeek(after delay: TimeInterval, duration: TimeInterval) {
        peekWork?.cancel()
        peekEndWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state.mode == .activity, self.activity?.peekText != nil else { return }
            self.send(.peek)
            let end = DispatchWorkItem { [weak self] in
                guard let self else { return }
                // Interactive peeks stay while the pointer is on them (hover exit ends them via the reducer).
                if self.state.isHovering, self.settings.liveActivities.interactive { return }
                self.send(.peekEnded)
            }
            self.peekEndWork = end
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: end)
        }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func pointerMoved(inside: Bool, suppressExit: Bool) {
        if inside {
            exitWork?.cancel()
            exitWork = nil
            panel?.ignoresMouseEvents = false
            if !state.isHovering { send(.hoverEntered) }
        } else if state.isHovering || panel?.ignoresMouseEvents == false {
            guard !suppressExit, exitWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.exitWork = nil
                if self.state.isHovering { self.send(.hoverExited) }
                if !self.state.isDropTarget { self.panel?.ignoresMouseEvents = true }
            }
            exitWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }
    }

    /// Drops text focus so "lock while typing" can't outlive the editing session.
    func endTyping() {
        if panel?.firstResponder is NSText { panel?.makeFirstResponder(nil) }
        if state.isTyping { send(.typingChanged(false)) }
    }

    func textFieldFocused(_ focused: Bool) {
        if focused { panel?.allowsKey = true; panel?.makeKey() }
        send(.typingChanged(focused))
    }

    func handleScroll(_ event: NSEvent) {
        guard settings.gestures.allowGestures, event.hasPreciseScrollingDeltas else { return }
        if state.mode == .open, isInsideScrollView(event) { return }
        let phase: NookCore.ScrollPhase
        if event.momentumPhase != [] { phase = .momentum }
        else if event.phase.contains(.began) { phase = .began }
        else if event.phase.contains(.ended) || event.phase.contains(.cancelled) { phase = .ended }
        else { phase = .changed }
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        guard let g = scroll.ingest(fingerDX: sign * event.scrollingDeltaX, fingerDY: sign * event.scrollingDeltaY, phase: phase) else { return }
        switch g {
        case .down: send(.swipeDown)
        case .up:
            if state.mode == .activity { services.activities.dismissCurrent(on: displayID) } else { send(.swipeUp) }
        case .left, .right:
            if settings.gestures.horizontalMedia, state.mode != .open || settings.nook.widgets.contains(where: { $0.kind == .media }) {
                services.media.handleSwipe(g)
            }
        }
    }

    private func isInsideScrollView(_ event: NSEvent) -> Bool {
        var v = panel?.contentView?.hitTest(event.locationInWindow)
        while let view = v {
            if view is NSScrollView { return true }
            v = view.superview
        }
        return false
    }

    // MARK: drops

    func updateDropHover(localPoint: CGPoint) {
        hoveredDropTarget = dropTargetFrames.first { $0.value.contains(localPoint) }?.key ?? .tray
    }

    /// Files, or (from browsers etc.) images / links / text, dropped on a target.
    func handleDrop(_ pb: NSPasteboard) -> Bool {
        let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let airdrop = hoveredDropTarget == .airdrop
        hoveredDropTarget = nil
        if airdrop {
            let items: [Any] = urls.isEmpty ? (NSImage(pasteboard: pb).map { [$0] } ?? pb.string(forType: .string).map { [$0] } ?? []) : urls
            guard !items.isEmpty else { return false }
            services.tray.share(items)
        } else {
            if urls.isEmpty {
                guard services.tray.paste(from: pb) else { return false } // nothing readable: don't flip to an empty Tray
            } else {
                services.tray.add(urls, move: NSEvent.modifierFlags.contains(.option))
            }
            tab = .tray
        }
        return true
    }
}
