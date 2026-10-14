import Foundation

public enum AdapterDecodeError: Error { case malformed }

/// Decodes `mediaremote-adapter stream` JSON lines, merging diffs into the last full payload.
public struct AdapterStreamDecoder {
    private var payload: [String: Any] = [:]
    private var receivedAt = Date()

    public init() {}

    public mutating func ingest(line: String, now: Date = Date()) throws -> NowPlaying? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
            throw AdapterDecodeError.malformed
        }
        guard obj["type"] as? String == "data" else { return current }
        let incoming = obj["payload"] as? [String: Any] ?? [:]
        if obj["diff"] as? Bool == true {
            for (k, v) in incoming {
                if v is NSNull { payload[k] = nil } else { payload[k] = v }
            }
        } else {
            payload = incoming
        }
        receivedAt = now
        return current
    }

    private var current: NowPlaying? {
        guard let title = payload["title"] as? String, !title.isEmpty else { return nil }
        let playing = payload["playing"] as? Bool ?? false
        return NowPlaying(
            title: title,
            artist: payload["artist"] as? String ?? "",
            album: payload["album"] as? String ?? "",
            duration: (payload["duration"] as? NSNumber)?.doubleValue ?? 0,
            elapsedAtTimestamp: (payload["elapsedTime"] as? NSNumber)?.doubleValue ?? 0,
            timestamp: Self.date(payload["timestamp"]) ?? receivedAt,
            playbackRate: (payload["playbackRate"] as? NSNumber)?.doubleValue ?? (playing ? 1 : 0),
            isPlaying: playing,
            bundleID: payload["parentApplicationBundleIdentifier"] as? String ?? payload["bundleIdentifier"] as? String ?? "",
            artworkData: (payload["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        )
    }

    private static func date(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}
