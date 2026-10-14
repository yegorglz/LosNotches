import AppKit
import NookCore
import SwiftUI

@MainActor
@Observable
final class MediaController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    private(set) var tint: Color?
    private(set) var snapshot = MediaSourceSnapshot()

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private let adapter = MediaAdapterProcess()
    @ObservationIgnored private let music = AppleScriptMediaSource(app: .music)
    @ObservationIgnored private let spotify = AppleScriptMediaSource(app: .spotify)
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var lastTrackKey: String?
    @ObservationIgnored private var pausedAt: Date?

    init(settings: SettingsStore, activities: LiveActivityCenter) {
        self.settings = settings
        self.activities = activities
    }

    var availableSources: [MediaSourcePreference] {
        var s: [MediaSourcePreference] = [.automatic]
        if snapshot.appleMusic != nil { s.append(.appleMusic) }
        if snapshot.spotify != nil { s.append(.spotify) }
        return s
    }

    func start() {
        adapter?.onUpdate = { [weak self] n in self?.snapshot.system = n; self?.recompute() }
        music.onUpdate = { [weak self] n in self?.snapshot.appleMusic = n; self?.recompute() }
        spotify.onUpdate = { [weak self] n in self?.snapshot.spotify = n; self?.recompute() }
        adapter?.start()
        // Both poll at 1 Hz only while their app runs, so the source switcher can offer them.
        music.start()
        spotify.start()
        observeChanges({ [settings] in _ = settings.settings.media.preferredSource }) { [weak self] in self?.recompute() }
        observeChanges({ [settings] in _ = settings.settings.liveActivities.inactivityTimeoutSeconds }) { [weak self] in self?.recompute() }
    }

    func stop() { adapter?.stop() }

    private func recompute() {
        var n = MediaSourceSelector.select(snapshot, preference: settings.settings.media.preferredSource)
        // AppleScript sources carry no artwork: borrow the system's when it is the same track.
        if let cur = n, cur.artworkData == nil, let sys = snapshot.system, sys.bundleID == cur.bundleID, sys.title == cur.title {
            n?.artworkData = sys.artworkData
        }
        nowPlaying = n
        updateArtwork()
        updateActivity()
    }

    private func updateArtwork() {
        let key = nowPlaying?.trackKey
        guard key != artworkKey || (artwork == nil && nowPlaying?.artworkData != nil) else { return }
        artworkKey = key
        artwork = nowPlaying?.artworkData.flatMap(NSImage.init(data:))
        if let cg = artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil), let c = ArtworkTint.averageColor(of: cg) {
            // Lift very dark covers so the tint stays visible on black.
            let lift = max(0, 0.45 - max(c.r, c.g, c.b))
            tint = Color(red: min(1, c.r + lift), green: min(1, c.g + lift), blue: min(1, c.b + lift))
        } else {
            tint = nil
        }
    }

    private func updateActivity() {
        guard let n = nowPlaying else {
            activities.remove(id: "media")
            lastTrackKey = nil
            return
        }
        if n.isPlaying { pausedAt = nil } else if pausedAt == nil { pausedAt = Date() }
        let changed = lastTrackKey != nil && lastTrackKey != n.trackKey
        lastTrackKey = n.trackKey
        let expires = pausedAt.map { $0 + settings.settings.liveActivities.inactivityTimeoutSeconds }
        if let expires, expires <= Date() {
            activities.remove(id: "media")
            return
        }
        let peek = n.artist.isEmpty ? n.title : "\(n.title) — \(n.artist)"
        activities.upsert(LiveActivity(id: "media", kind: .media, revision: n.trackKey.hashValue, expiresAt: expires, peekText: peek))
        if changed, n.isPlaying, settings.settings.liveActivities.showSongChange {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.activities.requestPeek(id: "media", seconds: 2.5) }
        }
    }

    // MARK: commands

    private var route: (send: (MediaCommand) -> Void, seek: (TimeInterval) -> Void)? {
        guard let n = nowPlaying else { return nil }
        if n == snapshot.appleMusic || (snapshot.appleMusic != nil && n.bundleID == "com.apple.Music" && settings.settings.media.preferredSource == .appleMusic) {
            return (music.send, music.seek)
        }
        if n == snapshot.spotify || (snapshot.spotify != nil && n.bundleID == "com.spotify.client" && settings.settings.media.preferredSource == .spotify) {
            return (spotify.send, spotify.seek)
        }
        guard let adapter else { return nil }
        return (adapter.send, adapter.seek)
    }

    func send(_ c: MediaCommand) { route?.send(c) }
    func seek(to t: TimeInterval) { route?.seek(t) }

    func handleSwipe(_ g: SwipeGesture) {
        guard nowPlaying != nil, let c = MediaGestureMap.command(for: g, inverted: settings.settings.gestures.invertMedia) else { return }
        send(c)
        if !settings.settings.gestures.disableHaptics { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
    }
}
