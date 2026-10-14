import AppKit
import NookCore

@MainActor
final class AppServices {
    static var shared: AppServices!

    let settings = SettingsStore()
    let supportDir = AppPaths.supportDirectory()
    lazy var activities = LiveActivityCenter(settings: settings)
    lazy var media = MediaController(settings: settings, activities: activities)
    lazy var hud = HUDController(settings: settings, activities: activities)
    lazy var calendar = CalendarService(settings: settings, activities: activities)
    lazy var todos = TodoStore(directory: supportDir)
    lazy var timers = TimersStore(directory: supportDir, activities: activities)
    lazy var notes = NotesStore(directory: supportDir)
    lazy var tray = TrayService(directory: supportDir, activities: activities)
    lazy var power = PowerMonitor(settings: settings, activities: activities)
    lazy var bluetooth = BluetoothMonitor(activities: activities)
    lazy var camera = CameraController(settings: settings)
    lazy var shortcuts = ShortcutsService()
    lazy var permissions = PermissionsCenter()
    lazy var windows = ScreenWindowManager(services: self)
    lazy var fullscreen = FullscreenMonitor()

    func start() {
        windows.start()
        media.start()
        hud.start()
        calendar.start()
        timers.start()
        power.start()
        bluetooth.start()
        tray.start()
        fullscreen.onChange = { [weak self] id, isFS in self?.windows.setFullscreen(isFS, displayID: id) }
        fullscreen.start()
    }

    /// Flushes anything with pending writes.
    func flushAll() {
        notes.flush()
    }
}
