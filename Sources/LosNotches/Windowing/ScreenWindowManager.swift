import AppKit
import NookCore
import SwiftUI

@MainActor
final class ScreenWindowManager {
    private let services: AppServices
    private(set) var viewModels: [UInt32: NotchViewModel] = [:]
    private var panels: [UInt32: NotchPanel] = [:]
    private var metrics: [ScreenMetrics] = []
    private lazy var tracker = MouseTracker(manager: self)

    init(services: AppServices) { self.services = services }

    var mainModel: NotchViewModel? {
        let id = (NSScreen.screens.first { NotchGeometry.hasNotch(ScreenMetrics($0)) } ?? NSScreen.main)?.displayID
        return id.flatMap { viewModels[$0] } ?? viewModels.values.first
    }

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        observeChanges({ [services] in
            _ = services.settings.settings.general.enableOnNonNotchScreens
            _ = services.settings.settings.general.notchWidthFineTune
            _ = services.settings.settings.general.notchHeightFineTune
        }) { [weak self] in self?.rebuild(force: true) }
        tracker.start()
    }

    func setFullscreen(_ isFullscreen: Bool, displayID: UInt32) {
        services.activities.setFullscreen(isFullscreen, displayID: displayID)
        viewModels[displayID]?.send(.fullscreenChanged(isFullscreen))
        services.hud.refresh()
    }

    func rebuild(force: Bool = false) {
        let showPlain = services.settings.settings.general.enableOnNonNotchScreens
        let new = NSScreen.screens.map(ScreenMetrics.init).filter { showPlain || NotchGeometry.hasNotch($0) }
        let diff = ScreenDiff.compute(old: metrics, new: new)
        metrics = new
        for id in diff.removed {
            panels[id]?.orderOut(nil)
            panels[id]?.close()
            panels[id] = nil
            viewModels[id] = nil
        }
        for m in new where diff.added.contains(m.displayID) { makePanel(for: m) }
        for m in new where diff.changed.contains(m.displayID) || force {
            viewModels[m.displayID]?.metrics = m
            panels[m.displayID]?.setFrame(NotchGeometry.windowFrame(m), display: true)
        }
    }

    private func makePanel(for m: ScreenMetrics) {
        let model = NotchViewModel(metrics: m, services: services)
        let panel = NotchPanel(frame: NotchGeometry.windowFrame(m))
        let host = NotchHostingView(rootView: NotchRootView(model: model))
        host.model = model
        panel.contentView = host
        model.panel = panel
        panel.onScroll = { [weak model] e in model?.handleScroll(e) }
        panel.orderFrontRegardless()
        viewModels[m.displayID] = model
        panels[m.displayID] = panel
        let id = m.displayID
        model.syncActivity()
        observeChanges({ [services] in _ = services.activities.current(for: id) }, while: { [weak model] in model != nil }) { [weak model] in
            model?.syncActivity()
        }
        // Typing focus ends when the user clicks into another app.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak model] _ in
            MainActor.assumeIsolated { model?.endTyping() }
        }
    }
}
