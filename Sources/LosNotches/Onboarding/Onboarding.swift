import AppKit
import ApplicationServices
import AVFoundation
import CoreBluetooth
import EventKit
import SwiftUI

enum Permission: CaseIterable, Identifiable {
    case accessibility, calendar, camera, bluetooth, automation
    var id: Self { self }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .calendar: "Calendar"
        case .camera: "Camera"
        case .bluetooth: "Bluetooth"
        case .automation: "Automation"
        }
    }

    var reason: String {
        switch self {
        case .accessibility: "Volume & brightness HUD replacement."
        case .calendar: "Calendar widget and live activity."
        case .camera: "Mirror widget."
        case .bluetooth: "Device connect / disconnect activity."
        case .automation: "Controlling Music and Spotify. Asked on first use."
        }
    }

    var settingsURL: URL {
        let pane = switch self {
        case .accessibility: "Privacy_Accessibility"
        case .calendar: "Privacy_Calendars"
        case .camera: "Privacy_Camera"
        case .bluetooth: "Privacy_Bluetooth"
        case .automation: "Privacy_Automation"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }
}

enum PermissionStatus { case granted, denied, notDetermined, askedOnFirstUse }

@MainActor
@Observable
final class PermissionsCenter {
    private var version = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var bluetoothProbe: CBCentralManager?

    func status(_ p: Permission) -> PermissionStatus {
        _ = version
        switch p {
        case .accessibility: return AXIsProcessTrusted() ? .granted : .notDetermined
        case .calendar:
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .camera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .bluetooth:
            switch CBCentralManager.authorization {
            case .allowedAlways: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .automation: return .askedOnFirstUse
        }
    }

    func refresh() { version += 1 }

    func request(_ p: Permission) {
        switch (p, status(p)) {
        case (.accessibility, _): AppServices.shared.hud.requestAccessibility()
        case (.calendar, .notDetermined): Task { await AppServices.shared.calendar.requestAccess(); refresh() }
        case (.camera, .notDetermined): AppServices.shared.camera.requestAccess()
        case (.bluetooth, .notDetermined): bluetoothProbe = CBCentralManager() // triggers the system prompt
        default: NSWorkspace.shared.open(p.settingsURL)
        }
        refresh()
    }

    /// Poll every 2 s while a permissions list is visible (grants happen in System Settings).
    func setWatching(_ on: Bool) {
        timer?.invalidate()
        timer = on ? Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } } : nil
    }
}

struct PermissionsList: View {
    private var center: PermissionsCenter { AppServices.shared.permissions }
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            ForEach(Permission.allCases) { p in
                let st = center.status(p)
                HStack(spacing: 8) {
                    Image(systemName: st == .granted ? "checkmark.circle.fill" : st == .askedOnFirstUse ? "info.circle" : "circle")
                        .foregroundStyle(st == .granted ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.title).font(.system(size: compact ? 11 : 13, weight: .semibold))
                        Text(p.reason).font(.system(size: compact ? 9 : 11)).opacity(0.6)
                    }
                    Spacer()
                    if st != .granted, st != .askedOnFirstUse {
                        Button("Grant") { center.request(p) }.controlSize(compact ? .mini : .small)
                    }
                }
            }
        }
        .onAppear { center.setWatching(true) }
        .onDisappear { center.setWatching(false) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in center.refresh() }
    }
}

struct OnboardingView: View {
    let model: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to LosNotches!").font(.system(size: 16, weight: .bold))
                hint("cursorarrow.click", "Click to open the Nook, where your widgets live.")
                hint("hand.draw", "Swipe vertically to open, close or hide the notch.")
                hint("doc.on.doc", "Drag and drop files to access multiple functions.")
                hint("cursorarrow.click.2", "Right click it for settings.")
                Spacer()
                Button("Done") { AppServices.shared.settings.settings.general.onboardingCompleted = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            .frame(width: 330, alignment: .leading)
            ScrollView(.vertical, showsIndicators: false) { PermissionsList(compact: true) }
        }
        .foregroundStyle(.white)
        .padding(.top, max(model.closedScreenRect.height, 28) + 4)
        .padding(.horizontal, 26).padding(.bottom, 14)
    }

    private func hint(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).frame(width: 18)
            Text(text).font(.system(size: 11))
        }
        .opacity(0.85)
    }
}
