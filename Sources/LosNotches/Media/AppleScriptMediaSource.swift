import AppKit
import NookCore

/// Polls Music or Spotify through AppleScript. Never launches the app (every script checks `is running`).
final class AppleScriptMediaSource {
    enum App {
        case music, spotify
        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
        var name: String { self == .music ? "Music" : "Spotify" }
    }

    let app: App
    var onUpdate: ((NowPlaying?) -> Void)?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "losnotches.applescript")
    private var lastWasNil = true

    init(app: App) { self.app = app }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    func stop() { timer?.invalidate(); timer = nil }

    private var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty }

    private func poll() {
        guard isRunning else {
            if !lastWasNil { lastWasNil = true; onUpdate?(nil) }
            return
        }
        let source = statusScript
        let bundleID = app.bundleID
        queue.async { [weak self] in
            let out = Self.run(source)
            let now = out.flatMap { AppleScriptNowPlayingParser.parse($0, bundleID: bundleID, now: Date()) }
            DispatchQueue.main.async {
                self?.lastWasNil = now == nil
                self?.onUpdate?(now)
            }
        }
    }

    func send(_ c: MediaCommand) {
        let verb: String
        switch c {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .togglePlayPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        }
        command(verb)
    }

    func seek(to seconds: TimeInterval) { command("set player position to \(Int(seconds))") }

    private func command(_ verb: String) {
        let src = "if application \"\(app.name)\" is running then tell application \"\(app.name)\" to \(verb)"
        queue.async { _ = Self.run(src) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.poll() }
    }

    private var statusScript: String {
        let sep = "(character id 31)"
        let duration = app == .spotify ? "((duration of t) / 1000)" : "(duration of t)"
        return """
        if application "\(app.name)" is running then
            tell application "\(app.name)"
                try
                    set s to player state as string
                    if s is "stopped" then return "stopped"
                    set t to current track
                    return s & \(sep) & (name of t) & \(sep) & (artist of t) & \(sep) & (album of t) & \(sep) & (\(duration) as string) & \(sep) & ((player position) as string)
                on error
                    return "stopped"
                end try
            end tell
        else
            return "NOT_RUNNING"
        end if
        """
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    }
}
