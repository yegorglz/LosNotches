import Foundation
import IOKit.ps
import NookCore
import SwiftUI

@MainActor
@Observable
final class PowerMonitor {
    private(set) var snapshot: PowerSnapshot?
    private(set) var lastEvent: BatteryEvent?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private var detector: BatteryTransitionDetector
    @ObservationIgnored private var source: CFRunLoopSource?

    init(settings: SettingsStore, activities: LiveActivityCenter) {
        self.settings = settings
        self.activities = activities
        detector = BatteryTransitionDetector(lowThreshold: settings.settings.liveActivities.lowBatteryThreshold)
    }

    func start() {
        guard Self.read() != nil else { return } // desktop Mac: no internal battery
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ ctx in
            let me = Unmanaged<PowerMonitor>.fromOpaque(ctx!).takeUnretainedValue()
            MainActor.assumeIsolated { me.update() }
        }, ctx)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
        update()
    }

    private func update() {
        guard let s = Self.read() else { return }
        snapshot = s
        detector.lowThreshold = settings.settings.liveActivities.lowBatteryThreshold
        guard let e = detector.ingest(s) else { return }
        lastEvent = e
        let text: String
        switch e {
        case .pluggedIn(let p): text = "Charging · \(p)%"
        case .unplugged(let p): text = "On battery · \(p)%"
        case .full: text = "Fully charged"
        case .low(let p): text = "Low battery · \(p)%"
        }
        activities.upsert(LiveActivity(id: "battery", kind: .battery, revision: text.hashValue, expiresAt: Date() + 4, peekText: text))
    }

    private static func read() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let cur = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            return PowerSnapshot(isPluggedIn: d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                                 isCharging: d[kIOPSIsChargingKey] as? Bool ?? false,
                                 percent: max > 0 ? cur * 100 / max : cur,
                                 isCharged: d[kIOPSIsChargedKey] as? Bool ?? false)
        }
        return nil
    }
}

struct BatteryWing: View {
    let side: WingSide
    var body: some View {
        let power = AppServices.shared.power
        let s = power.snapshot
        let low: Bool = if case .low = power.lastEvent { true } else { false }
        if side == .left {
            Image(systemName: s?.isPluggedIn == true ? "battery.100percent.bolt" : symbol(s?.percent ?? 0))
                .font(.system(size: 13))
                .foregroundStyle(low ? .red : s?.isPluggedIn == true ? .green : .white)
        } else {
            Text("\(s?.percent ?? 0)%").font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(low ? .red : .white)
        }
    }
    private func symbol(_ p: Int) -> String {
        p > 87 ? "battery.100percent" : p > 62 ? "battery.75percent" : p > 37 ? "battery.50percent" : p > 12 ? "battery.25percent" : "battery.0percent"
    }
}
