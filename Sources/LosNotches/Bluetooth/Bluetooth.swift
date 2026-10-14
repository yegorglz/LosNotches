import CoreBluetooth
import IOBluetooth
import NookCore
import SwiftUI

@MainActor
@Observable
final class BluetoothMonitor: NSObject, CBCentralManagerDelegate {
    private(set) var lastName = ""
    private(set) var lastKind = BluetoothDeviceKind.other
    private(set) var lastConnected = true
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var connectNote: IOBluetoothUserNotification?
    @ObservationIgnored private var disconnectNotes: [String: IOBluetoothUserNotification] = [:]
    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var started = false

    init(activities: LiveActivityCenter) {
        self.activities = activities
        super.init()
    }

    /// IOBluetooth blocks the calling thread while the Bluetooth permission prompt is pending,
    /// so it is only touched once CoreBluetooth reports access (the prompt itself is async).
    func start() {
        switch CBCentralManager.authorization {
        case .allowedAlways: startWatching()
        case .notDetermined: central = CBCentralManager(delegate: self, queue: .main)
        default: return
        }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if CBCentralManager.authorization == .allowedAlways { startWatching() }
        }
    }

    private func startWatching() {
        guard !started else { return }
        started = true
        startedAt = Date()
        for d in (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []) where d.isConnected() { watchDisconnect(d) }
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        watchDisconnect(device)
        // Registering replays already-connected devices; don't announce those.
        guard Date().timeIntervalSince(startedAt) > 3 else { return }
        announce(device, connected: true)
    }

    @objc private func disconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        disconnectNotes[device.addressString ?? ""]?.unregister()
        disconnectNotes[device.addressString ?? ""] = nil
        announce(device, connected: false)
    }

    private func watchDisconnect(_ d: IOBluetoothDevice) {
        let key = d.addressString ?? ""
        guard disconnectNotes[key] == nil else { return }
        disconnectNotes[key] = d.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
    }

    private func announce(_ d: IOBluetoothDevice, connected: Bool) {
        lastName = d.name ?? "Bluetooth device"
        lastKind = BluetoothDeviceKind.from(major: d.deviceClassMajor, minor: d.deviceClassMinor)
        lastConnected = connected
        let text = "\(lastName) · \(connected ? "Connected" : "Disconnected")"
        activities.upsert(LiveActivity(id: "bluetooth", kind: .bluetooth, revision: text.hashValue, expiresAt: Date() + 3, peekText: text))
        activities.requestPeek(id: "bluetooth", seconds: 2.5)
    }
}

struct BluetoothWing: View {
    let side: WingSide
    var body: some View {
        let bt = AppServices.shared.bluetooth
        if side == .left {
            Image(systemName: bt.lastKind.symbolName).font(.system(size: 13))
        } else {
            HStack(spacing: 3) {
                Circle().fill(bt.lastConnected ? Color.green : Color.red).frame(width: 6, height: 6)
                Text(bt.lastConnected ? "On" : "Off").font(.system(size: 11, weight: .semibold))
            }
        }
    }
}
