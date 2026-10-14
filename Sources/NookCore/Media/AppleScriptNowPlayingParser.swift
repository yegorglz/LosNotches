import Foundation

/// Parses our own AppleScript output: `state␟title␟artist␟album␟durationSeconds␟positionSeconds` (␟ = U+001F).
public enum AppleScriptNowPlayingParser {
    public static let separator = "\u{1F}"

    public static func parse(_ output: String, bundleID: String, now: Date) -> NowPlaying? {
        let f = output.trimmingCharacters(in: .newlines).components(separatedBy: separator)
        guard f.count == 6, f[0] == "playing" || f[0] == "paused" else { return nil }
        let num = { (s: String) in Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let playing = f[0] == "playing"
        return NowPlaying(title: f[1], artist: f[2], album: f[3], duration: num(f[4]), elapsedAtTimestamp: num(f[5]),
                          timestamp: now, playbackRate: playing ? 1 : 0, isPlaying: playing, bundleID: bundleID)
    }
}
