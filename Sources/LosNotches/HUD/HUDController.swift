import AppKit
import ApplicationServices
import NookCore
import SwiftUI

enum HUDKind { case volume, brightness }

@MainActor
@Observable
final class HUDController {
    private(set) var needsAccessibility = false
    private(set) var kind: HUDKind = .volume
    private(set) var level: Float = 0
    private(set) var muted = false

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private let tap = MediaKeyTap()
    @ObservationIgnored private let suppressor = OSDSuppressor()
    @ObservationIgnored private var retryTimer: Timer?
    @ObservationIgnored private var ownChangeUntil = Date.distantPast

    init(settings: SettingsStore, activities: LiveActivityCenter) {
        self.settings = settings
        self.activities = activities
    }

    func start() {
        tap.handler = { [weak self] e, fine in
            MainActor.assumeIsolated { self?.handleKey(e, fine: fine) ?? false }
        }
        SystemVolume.observe { [weak self] in self?.externalVolumeChange() }
        observeChanges({ [settings] in _ = settings.settings.liveActivities.hudReplacement }) { [weak self] in self?.apply() }
        apply()
    }

    /// Always leaves the system OSD running.
    func shutdown() {
        tap.stop()
        suppressor.restore()
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func apply() {
        let enabled = settings.settings.liveActivities.hudReplacement
        let active = enabled && AXIsProcessTrusted() && tap.start()
        needsAccessibility = enabled && !active
        if HUDActivationPolicy.shouldSuspendOSD(replacementEnabled: enabled, tapActive: active) {
            suppressor.suspend()
        } else {
            tap.stop()
            suppressor.restore()
        }
        // Accessibility can be granted (or revoked by a rebuild) while running: keep checking.
        retryTimer?.invalidate()
        retryTimer = nil
        if enabled {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if AXIsProcessTrusted() != self.tap.isActive || self.needsAccessibility && AXIsProcessTrusted() {
                        if !AXIsProcessTrusted() { self.tap.stop() }
                        self.apply()
                    }
                }
            }
        }
    }

    private func handleKey(_ e: MediaKeyEvent, fine: Bool) -> Bool {
        guard settings.settings.liveActivities.hudReplacement else { return false }
        switch e.key {
        case .soundUp, .soundDown:
            guard let cur = SystemVolume.get() else { return false }
            if e.isDown {
                let next = LevelStep.apply(current: cur, up: e.key == .soundUp, fine: fine)
                guard SystemVolume.set(next) else { return false }
                if SystemVolume.isMuted() == true { _ = SystemVolume.setMuted(false) }
                show(.volume, next, muted: false)
            }
            return true
        case .mute:
            guard let m = SystemVolume.isMuted() else { return false }
            if e.isDown, !e.isRepeat {
                guard SystemVolume.setMuted(!m) else { return false }
                show(.volume, SystemVolume.get() ?? 0, muted: !m)
            }
            return true
        case .brightnessUp, .brightnessDown:
            guard let cur = DisplayBrightness.get() else { return false }
            if e.isDown {
                let next = LevelStep.apply(current: cur, up: e.key == .brightnessUp, fine: fine)
                guard DisplayBrightness.set(next) else { return false }
                show(.brightness, next, muted: false)
            }
            return true
        default:
            return false
        }
    }

    private func externalVolumeChange() {
        guard settings.settings.liveActivities.hudReplacement, tap.isActive, Date() > ownChangeUntil else { return }
        show(.volume, SystemVolume.get() ?? 0, muted: SystemVolume.isMuted() ?? false, own: false)
    }

    private func show(_ k: HUDKind, _ l: Float, muted m: Bool, own: Bool = true) {
        if own { ownChangeUntil = Date() + 0.3 }
        kind = k
        level = l
        muted = m
        activities.upsert(LiveActivity(id: "hud", kind: .hud, revision: Int(l * 1000) + (m ? 1 : 0), expiresAt: Date() + 1.5))
        if !settings.settings.gestures.disableHaptics, own, l == 0 || l == 1 {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
}

struct HUDWing: View {
    let side: WingSide
    private var hud: HUDController { AppServices.shared.hud }

    var body: some View {
        if side == .left {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).contentTransition(.symbolEffect(.replace))
        } else {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(barColor).frame(width: 52 * CGFloat(hud.muted ? 0 : hud.level))
            }
            .frame(width: 52, height: 6)
            .animation(.nook, value: hud.level)
        }
    }

    private var barColor: Color {
        AppServices.shared.settings.settings.liveActivities.hudMonochrome || hud.kind == .brightness ? .white : .accentColor
    }

    private var symbol: String {
        if hud.kind == .brightness { return hud.level < 0.5 ? "sun.min.fill" : "sun.max.fill" }
        if hud.muted || hud.level == 0 { return "speaker.slash.fill" }
        return hud.level < 0.34 ? "speaker.wave.1.fill" : hud.level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}
