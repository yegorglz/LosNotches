import AppKit
import NookCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: AppServices!
    private var statusItem: StatusItemController?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A previous run may have crashed while the system OSD was frozen.
        OSDSuppressor().restore()
        installSignalHandlers()
        services = AppServices()
        AppServices.shared = services
        services.start()
        if !services.settings.settings.general.onboardingCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.services.windows.mainModel?.send(.click) }
        }
        statusItem = StatusItemController(services: services)
        #if DEBUG
        installDebugHook()
        #endif
    }

    #if DEBUG
    /// Debug builds only: drive UI states for screenshots, e.g. post "dev.losnotches.debug" with object "open".
    private func installDebugHook() {
        DistributedNotificationCenter.default().addObserver(forName: .init("dev.losnotches.debug"), object: nil, queue: .main) { n in
            MainActor.assumeIsolated {
                let s = AppServices.shared!
                let m = s.windows.mainModel
                let parts = (n.object as? String ?? "").split(separator: ":").map(String.init)
                switch parts.first {
                case "open": m?.send(.click)
                case "close": m?.send(.closeRequested)
                case "drag": m?.send(.dragEntered)
                case "dragend": m?.send(.dragExited)
                case "settings": SettingsWindowController.shared.show(tab: SettingsTab(rawValue: parts.last ?? "") ?? .general)
                case "activity":
                    let kind = LiveActivityKind(rawValue: parts.last ?? "") ?? .hud
                    s.activities.upsert(LiveActivity(id: "debug", kind: kind, revision: Int.random(in: 0...999), expiresAt: Date() + 6, peekText: "Debug \(kind.title)"))
                case "peek": s.activities.requestPeek(id: "debug", seconds: 4)
                case "appearance":
                    var look = AppearanceSettings()
                    if parts.last == "demo" {
                        look.openCornerRadius = 36; look.islandBorderWidth = 1.5; look.islandBorderOpacity = 0.5
                        look.widgetBackgroundOpacity = 0.08; look.widgetBorderWidth = 1; look.widgetBorderColorHex = "#FF9F0A"; look.widgetBorderOpacity = 0.6
                    }
                    s.settings.settings.appearance = look
                case "menu":
                    // Pops a context menu over the open Nook for 3 s to check it isn't drawn under the island.
                    guard let m, let view = m.panel?.contentView else { break }
                    let menu = NSMenu()
                    for t in ["Open", "Show in Finder", "Send via AirDrop", "Remove from tray"] { menu.addItem(withTitle: t, action: nil, keyEquivalent: "") }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { menu.cancelTracking() }
                    menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.midX, y: view.bounds.maxY - 80), in: view)
                case "tab": m?.tab = parts.last == "tray" ? .tray : .nook
                case "effect": s.settings.settings.media.effect = MediaEffect(rawValue: parts.last ?? "") ?? .waves
                case "translucent": s.settings.settings.appearance.translucentBackground = parts.last == "on"
                case "todo": s.todos.mutate { $0.add(title: parts.dropFirst().joined(separator: ":"), now: Date()) }
                case "todostar", "tododone", "todoclear":
                    let title = parts.dropFirst().joined(separator: ":")
                    s.todos.mutate { list in
                        guard let item = list.items.first(where: { $0.title == title }) else { return }
                        switch parts[0] {
                        case "todostar": list.toggleStar(id: item.id)
                        case "tododone": list.toggleComplete(id: item.id, now: Date())
                        default: list.delete(id: item.id)
                        }
                    }
                case "onboarding": s.settings.settings.general.onboardingCompleted = parts.last == "done"
                case "widgets":
                    s.settings.settings.nook.widgets = parts.dropFirst().compactMap { p in
                        let kv = p.split(separator: "=")
                        return WidgetKind(rawValue: String(kv[0])).map { WidgetPlacement(kind: $0, widthCells: Int(kv.last ?? "") ?? $0.minCells) }
                    }
                default: break
                }
            }
        }
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        services?.flushAll()
        services?.hud.shutdown()
        services?.media.stop()
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.services?.flushAll()
                    self?.services?.hud.shutdown()
                    self?.services?.media.stop()
                }
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }
    }
}
