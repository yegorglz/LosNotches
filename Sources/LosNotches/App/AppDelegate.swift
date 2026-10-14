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
