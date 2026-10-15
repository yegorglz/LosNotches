import NookCore
import SwiftUI

struct GeneralSettingsView: View {
    @State private var loginError: String?
    @State private var confirmReset = false

    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "Startup") {
            Toggle("Launch at login", isOn: Binding(get: { LoginItem.isEnabled }, set: { on in
                do { try LoginItem.set(on); s.wrappedValue.general.launchAtLogin = on; loginError = nil }
                catch { loginError = error.localizedDescription }
            }))
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            Toggle("Show menu bar icon", isOn: s.general.showMenuBarIcon)
        }
        SettingsSection(title: "Notch", footer: "LosNotches tries its best to guess your notch size. Fine tune it so it matches your notch exactly.") {
            Toggle("Show on screens without a notch", isOn: s.general.enableOnNonNotchScreens)
            Toggle("Transparent handle (no-notch screens)", isOn: s.general.transparentHandle)
            LabeledSlider(title: "Notch width fine tune", value: s.general.notchWidthFineTune, range: -20...20)
            LabeledSlider(title: "Notch height fine tune", value: s.general.notchHeightFineTune, range: -20...20)
            Toggle("Show in fullscreen apps", isOn: s.general.showInFullscreen)
        }
        SettingsSection(title: "Interactivity") {
            Toggle("Open by clicking the notch", isOn: s.general.clickToOpen)
            Toggle("Always open on hover", isOn: s.general.alwaysOpenOnHover)
            Toggle("Prevent from closing on mouse leave", isOn: s.general.preventCloseOnMouseLeave)
            Toggle("Lock while typing", isOn: s.general.lockWhileTyping)
        }
        SettingsSection(title: "Reset") {
            Button("Reset all settings…", role: .destructive) { confirmReset = true }
                .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
                    Button("Reset", role: .destructive) { AppServices.shared.settings.reset() }
                } message: { Text("Your notes, to-dos, timers and tray files are kept.") }
        }
    }
}

struct AppearanceSettingsView: View {
    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "Island", footer: "Changes apply live. Open the Nook to preview the open shape.") {
            LabeledSlider(title: "Top flare radius", value: s.appearance.flareRadius, range: 0...16)
            LabeledSlider(title: "Closed corner radius", value: s.appearance.closedCornerRadius, range: 0...20)
            LabeledSlider(title: "Open corner radius", value: s.appearance.openCornerRadius, range: 0...48)
            LabeledSlider(title: "Border width", value: s.appearance.islandBorderWidth, range: 0...4, step: 0.5)
            HexColorPicker(title: "Border color", hex: s.appearance.islandBorderColorHex)
            LabeledSlider(title: "Border opacity (%)", value: percent(s.appearance.islandBorderOpacity), range: 0...100)
        }
        SettingsSection(title: "Widgets") {
            LabeledSlider(title: "Corner radius", value: s.appearance.widgetCornerRadius, range: 0...30)
            LabeledSlider(title: "Background opacity (%)", value: percent(s.appearance.widgetBackgroundOpacity), range: 0...40)
            LabeledSlider(title: "Border width", value: s.appearance.widgetBorderWidth, range: 0...3, step: 0.5)
            HexColorPicker(title: "Border color", hex: s.appearance.widgetBorderColorHex)
            LabeledSlider(title: "Border opacity (%)", value: percent(s.appearance.widgetBorderOpacity), range: 0...100)
            LabeledSlider(title: "Padding around widgets", value: s.general.widgetPadding, range: 0...20)
            Toggle("Show dividers between widgets", isOn: s.general.showDividers)
            Toggle("Prefer round buttons", isOn: s.general.preferRoundButtons)
        }
        SettingsSection(title: "Reset") {
            Button("Restore default appearance") { s.wrappedValue.appearance = AppearanceSettings() }
        }
    }

    private func percent(_ b: Binding<Double>) -> Binding<Double> {
        Binding(get: { (b.wrappedValue * 100).rounded() }, set: { b.wrappedValue = $0 / 100 })
    }
}

struct HexColorPicker: View {
    let title: String
    @Binding var hex: String
    var body: some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString }), supportsOpacity: false)
    }
}

extension Color {
    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
            Text(step < 1 ? String(format: "%.1f", value) : "\(Int(value))").monospacedDigit().frame(width: 30, alignment: .trailing)
        }
    }
}

struct GesturesSettingsView: View {
    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "Gestures") {
            Toggle("Allow gestures when hovering the notch", isOn: s.gestures.allowGestures)
            Toggle("Open/close the notch with vertical swipes", isOn: s.gestures.verticalOpenClose)
                .disabled(!s.wrappedValue.gestures.allowGestures)
            Toggle("Control media with horizontal swipes", isOn: s.gestures.horizontalMedia)
                .disabled(!s.wrappedValue.gestures.allowGestures)
            Toggle("Invert media gestures", isOn: s.gestures.invertMedia)
            Text("If on, a left swipe starts the next song; if off, the previous one.").font(.caption).foregroundStyle(.secondary)
        }
        SettingsSection(title: "Feedback") {
            Toggle("Disable haptics", isOn: s.gestures.disableHaptics)
        }
    }
}

struct NookSettingsView: View {
    @State private var shortcuts = AppServices.shared.shortcuts

    var body: some View {
        let s = settingsBinding
        let layout = NookGridLayout.layout(s.wrappedValue.nook.widgets)
        let used = s.wrappedValue.nook.widgets.reduce(0) { $0 + max($1.widthCells, $1.kind.minCells) }
        SettingsSection(title: "Widgets", footer: "Width is measured in cells. 1 cell = \(Int(NookGridLayout.cell)) pt. Total cells: \(NookGridLayout.maxCells), used: \(used).") {
            ForEach(Array(s.wrappedValue.nook.widgets.enumerated()), id: \.element.kind) { i, p in
                HStack {
                    Text(p.kind.title)
                    if layout.hidden.contains(p.kind) { Text("Hidden, it doesn't fit.").font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Stepper("Width: \(max(p.widthCells, p.kind.minCells))", value: s.nook.widgets[i].widthCells,
                            in: p.kind.minCells...NookGridLayout.maxCells)
                    Button { s.wrappedValue.nook.widgets.swapAt(i, i - 1) } label: { Image(systemName: "arrow.up") }.disabled(i == 0)
                    Button { s.wrappedValue.nook.widgets.swapAt(i, i + 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(i == s.wrappedValue.nook.widgets.count - 1)
                    Button { s.wrappedValue.nook.widgets.remove(at: i) } label: { Image(systemName: "minus.circle") }
                }
                .buttonStyle(.borderless)
            }
            let missing = WidgetKind.allCases.filter { k in !s.wrappedValue.nook.widgets.contains { $0.kind == k } }
            if !missing.isEmpty {
                Menu("Add widget") {
                    ForEach(missing, id: \.self) { k in
                        Button(k.title) { s.wrappedValue.nook.widgets.append(.init(kind: k, widthCells: k.minCells)) }
                    }
                }
                .fixedSize()
            }
        }
        SettingsSection(title: "Mirror") {
            Picker("Camera", selection: s.mirror.deviceUniqueID) {
                Text("Default").tag(String?.none)
                ForEach(AppServices.shared.camera.devices, id: \.id) { d in Text(d.name).tag(Optional(d.id)) }
            }
            Toggle("Mirror video", isOn: s.mirror.mirrored)
        }
        SettingsSection(title: "Shortcuts", footer: "Each column contains 2 rows (2 shortcuts).") {
            if shortcuts.all.isEmpty { Text("No shortcuts found.").foregroundStyle(.secondary) }
            ForEach(shortcuts.all, id: \.self) { name in
                Toggle(name, isOn: Binding(
                    get: { s.wrappedValue.content.shortcutNames.contains(name) },
                    set: { on in
                        if on { s.wrappedValue.content.shortcutNames.append(name) }
                        else { s.wrappedValue.content.shortcutNames.removeAll { $0 == name } }
                    }))
            }
        }
        .task { await shortcuts.reload() }
        SettingsSection(title: "Quick Apps") {
            ForEach(s.wrappedValue.content.quickAppPaths, id: \.self) { path in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 20, height: 20)
                    Text(FileManager.default.displayName(atPath: path))
                    Spacer()
                    Button { s.wrappedValue.content.quickAppPaths.removeAll { $0 == path } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
            Button("Add app…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.allowsMultipleSelection = true
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                if panel.runModal() == .OK {
                    for u in panel.urls where !s.wrappedValue.content.quickAppPaths.contains(u.path) {
                        s.wrappedValue.content.quickAppPaths.append(u.path)
                    }
                }
            }
        }
    }
}

struct LiveActivitiesSettingsView: View {
    private var hud: HUDController { AppServices.shared.hud }

    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "General") {
            Toggle("Enable live activities", isOn: s.liveActivities.enabled)
            Toggle("Enable Quick Peek", isOn: s.liveActivities.quickPeek)
            Text("Take a quick peek at useful info by hovering some of the live activities.").font(.caption).foregroundStyle(.secondary)
            Toggle("Show song change", isOn: s.liveActivities.showSongChange)
            Toggle("Unhide automatically", isOn: s.liveActivities.unhideAutomatically)
            Text("If enabled, live activities that have been dismissed (by swiping up) will automatically return.").font(.caption).foregroundStyle(.secondary)
            Toggle("Enable interactive activities", isOn: s.liveActivities.interactive)
            LabeledSlider(title: "Inactivity timeout (s)", value: s.liveActivities.inactivityTimeoutSeconds, range: 1...30)
        }
        SettingsSection(title: "Brightness/Volume HUD Replacement",
                        footer: "This setting requires you to provide LosNotches with accessibility permissions.") {
            Toggle("Replace the system volume and brightness HUD", isOn: s.liveActivities.hudReplacement)
            Toggle("Disable colors on audio HUD replacement", isOn: s.liveActivities.hudMonochrome)
            if hud.needsAccessibility, s.wrappedValue.liveActivities.hudReplacement {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Accessibility needed. The system HUD stays on until access is granted.")
                    Spacer()
                    Button("Grant access…") { hud.requestAccessibility() }
                }
            }
        }
        SettingsSection(title: "Battery") {
            Stepper("Low battery threshold: \(s.wrappedValue.liveActivities.lowBatteryThreshold)%",
                    value: s.liveActivities.lowBatteryThreshold, in: 5...50)
        }
        SettingsSection(title: "Activities") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("Activity").bold(); Text("Enabled").bold(); Text("Show in fullscreen").bold() }
                ForEach(LiveActivityKind.allCases, id: \.self) { k in
                    GridRow {
                        Text(k.title)
                        Toggle("", isOn: setBinding(s.liveActivities.enabledKinds, k)).labelsHidden()
                        Toggle("", isOn: setBinding(s.liveActivities.visibleInFullscreen, k)).labelsHidden()
                    }
                }
            }
        }
    }

    private func setBinding(_ set: Binding<Set<LiveActivityKind>>, _ k: LiveActivityKind) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(k) }, set: { on in
            if on { set.wrappedValue.insert(k) } else { set.wrappedValue.remove(k) }
        })
    }
}

struct MediaSettingsView: View {
    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "Source", footer: "Automatic follows whatever macOS shows as Now Playing. Choosing an app makes the Nook follow it when both are playing.") {
            Picker("Preferred source", selection: s.media.preferredSource) {
                ForEach(MediaSourcePreference.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }
        SettingsSection(title: "Appearance") {
            Picker("Effect type", selection: s.media.effect) {
                Text("Waves").tag(MediaEffect.waves)
                Text("None").tag(MediaEffect.none)
            }
            Toggle("Colored effects", isOn: s.media.coloredEffects)
            Text("If enabled, effects take the color of the current album; otherwise they are white.").font(.caption).foregroundStyle(.secondary)
            LabeledSlider(title: "Album corner radius", value: s.media.albumCornerRadius, range: 0...32)
        }
    }
}

struct CalendarSettingsView: View {
    private var calendar: CalendarService { AppServices.shared.calendar }

    var body: some View {
        let s = settingsBinding
        SettingsSection(title: "Calendars", footer: "Nothing selected means all calendars are shown.") {
            if calendar.authorization != .authorized {
                Button("Allow calendar access…") { Task { await calendar.requestAccess() } }
            }
            ForEach(calendar.calendars, id: \.id) { c in
                Toggle(isOn: Binding(
                    get: { s.wrappedValue.calendar.selectedCalendarIDs.contains(c.id) },
                    set: { on in
                        if on { s.wrappedValue.calendar.selectedCalendarIDs.append(c.id) }
                        else { s.wrappedValue.calendar.selectedCalendarIDs.removeAll { $0 == c.id } }
                    })) {
                    HStack { Circle().fill(Color(hex: c.colorHex)).frame(width: 8, height: 8); Text(c.title) }
                }
            }
        }
        SettingsSection(title: "Widget") {
            Stepper("Number of days behind: \(s.wrappedValue.calendar.daysBehind)", value: s.calendar.daysBehind, in: 0...7)
            Stepper("Number of days ahead: \(s.wrappedValue.calendar.daysAhead)", value: s.calendar.daysAhead, in: 1...14)
            Toggle("Show today's past events", isOn: s.calendar.showPastEventsToday)
        }
        SettingsSection(title: "Calendar Live Activity") {
            Stepper("Minutes before showing up: \(s.wrappedValue.calendar.activityMinutesBefore)", value: s.calendar.activityMinutesBefore, in: 1...30)
            Toggle("Show while in events", isOn: s.calendar.showWhileInEvent)
            Toggle("Show time elapsed while in events", isOn: s.calendar.showTimeElapsed)
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        SettingsSection(title: "LosNotches") {
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
            Text("Free, local, open. Your notch, actually useful.").foregroundStyle(.secondary)
            Button("See Tutorial") {
                AppServices.shared.settings.settings.general.onboardingCompleted = false
                AppServices.shared.windows.mainModel?.send(.click)
            }
        }
        SettingsSection(title: "Permissions") { PermissionsList() }
        SettingsSection(title: "Credits") {
            Text("Now Playing via mediaremote-adapter © Jonas van den Berg and contributors (BSD-3-Clause).").font(.caption)
        }
    }
}

extension Color {
    init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFF3B30
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
