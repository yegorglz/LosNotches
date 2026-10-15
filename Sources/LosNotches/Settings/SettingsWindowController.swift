import AppKit
import NookCore
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, nook, liveActivities, gestures, media, calendar, about
    var id: Self { self }
    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .nook: "Nook & Widgets"
        case .liveActivities: "Live Activities"
        case .gestures: "Gestures"
        case .media: "Media"
        case .calendar: "Calendar"
        case .about: "About"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .nook: "square.grid.3x1.below.line.grid.1x2"
        case .liveActivities: "capsule.inset.filled"
        case .gestures: "hand.draw"
        case .media: "play.circle"
        case .calendar: "calendar"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private static let frameKey = "losnotches.settingsFrame"
    private var window: NSWindow?
    private let selection = SettingsSelection()

    func show(tab: SettingsTab = .general) {
        selection.tab = tab
        if window == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "LosNotches Settings"
            w.isReleasedWhenClosed = false
            w.minSize = SettingsWindowFrame.minSize
            w.contentViewController = NSHostingController(rootView: SettingsRootView(selection: selection))
            w.delegate = self
            let saved = UserDefaults.standard.string(forKey: Self.frameKey).map(NSRectFromString).flatMap { $0 == .zero ? nil : $0 }
            w.setFrame(SettingsWindowFrame.sanitized(saved: saved, visible: NSScreen.main?.visibleFrame ?? .zero), display: false)
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidResize(_ notification: Notification) { saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    private func saveFrame() {
        if let f = window?.frame { UserDefaults.standard.set(NSStringFromRect(f), forKey: Self.frameKey) }
    }
}

@Observable final class SettingsSelection { var tab: SettingsTab = .general }

struct SettingsRootView: View {
    @Bindable var selection: SettingsSelection

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: Binding($selection.tab)) { tab in
                Label(tab.title, systemImage: tab.symbol).tag(tab)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selection.tab {
                    case .general: GeneralSettingsView()
                    case .appearance: AppearanceSettingsView()
                    case .nook: NookSettingsView()
                    case .liveActivities: LiveActivitiesSettingsView()
                    case .gestures: GesturesSettingsView()
                    case .media: MediaSettingsView()
                    case .calendar: CalendarSettingsView()
                    case .about: AboutSettingsView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(selection.tab.title)
        }
    }
}

/// Shorthand for the settings binding used by every tab.
@MainActor var settingsBinding: Binding<AppSettings> {
    let store = AppServices.shared.settings
    return Binding(get: { store.settings }, set: { store.settings = $0 })
}

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.bottom, 18)
    }
}
