import Foundation
import NookCore

@MainActor
@Observable
final class LiveActivityCenter {
    private(set) var queue = LiveActivityQueue()
    private var fullscreenDisplays: Set<UInt32> = []
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var timer: Timer?
    /// Bumped once per second while something can expire, so `current(for:)` re-evaluates.
    private var tick = 0

    init(settings: SettingsStore) { self.settings = settings }

    func upsert(_ a: LiveActivity) {
        queue.upsert(a)
        updateTimer()
    }

    func remove(id: String) {
        queue.remove(id: id)
        updateTimer()
    }

    func dismissCurrent(on displayID: UInt32) {
        if let a = current(for: displayID) { queue.dismiss(id: a.id) }
    }

    func current(for displayID: UInt32) -> LiveActivity? {
        _ = tick
        return queue.current(now: Date(), isFullscreen: fullscreenDisplays.contains(displayID), settings: settings.settings.liveActivities)
    }

    /// Whether an activity of `kind` could appear right now (ignoring other activities).
    func canShow(_ kind: LiveActivityKind) -> Bool {
        let s = settings.settings.liveActivities
        return s.enabled && s.enabledKinds.contains(kind) && (fullscreenDisplays.isEmpty || s.visibleInFullscreen.contains(kind))
    }

    func setFullscreen(_ on: Bool, displayID: UInt32) {
        if on { fullscreenDisplays.insert(displayID) } else { fullscreenDisplays.remove(displayID) }
    }

    func requestPeek(id: String, seconds: TimeInterval) {
        guard settings.settings.liveActivities.quickPeek else { return }
        for m in AppServices.shared.windows.viewModels.values where m.activity?.id == id { m.peek(seconds: seconds) }
    }

    private func updateTimer() {
        let needs = queue.all.contains { $0.expiresAt != nil }
        if needs, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.queue.purgeExpired(now: Date())
                    self.tick += 1
                    self.updateTimer()
                }
            }
        } else if !needs {
            timer?.invalidate()
            timer = nil
        }
    }
}
