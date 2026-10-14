import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let services: AppServices
    private var item: NSStatusItem?

    init(services: AppServices) {
        self.services = services
        super.init()
        apply()
        observeChanges({ _ = services.settings.settings.general.showMenuBarIcon }) { [weak self] in self?.apply() }
    }

    private func apply() {
        let show = services.settings.settings.general.showMenuBarIcon
        if show, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "LosNotches")
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Nook", action: #selector(openNook), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit LosNotches", action: #selector(quit), keyEquivalent: "q").target = self
            item.menu = menu
            self.item = item
        } else if !show, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    @objc private func openNook() { services.windows.mainModel?.send(.click) }
    @objc private func openSettings() { SettingsWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
