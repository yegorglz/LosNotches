import Foundation

public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var elapsedAtTimestamp: TimeInterval
    public var timestamp: Date
    public var playbackRate: Double
    public var isPlaying: Bool
    public var bundleID: String
    public var artworkData: Data?

    public init(title: String, artist: String = "", album: String = "", duration: TimeInterval = 0,
                elapsedAtTimestamp: TimeInterval = 0, timestamp: Date = Date(), playbackRate: Double = 1,
                isPlaying: Bool = true, bundleID: String = "", artworkData: Data? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedAtTimestamp = elapsedAtTimestamp
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.isPlaying = isPlaying
        self.bundleID = bundleID
        self.artworkData = artworkData
    }

    public func elapsed(at now: Date) -> TimeInterval {
        var t = isPlaying ? elapsedAtTimestamp + now.timeIntervalSince(timestamp) * playbackRate : elapsedAtTimestamp
        t = max(0, t)
        return duration > 0 ? min(t, duration) : t
    }

    public var trackKey: String { "\(bundleID)|\(title)|\(artist)|\(album)" }
}
