public struct MediaSourceSnapshot: Equatable, Sendable {
    public var system: NowPlaying?
    public var appleMusic: NowPlaying?
    public var spotify: NowPlaying?
    public init(system: NowPlaying? = nil, appleMusic: NowPlaying? = nil, spotify: NowPlaying? = nil) {
        self.system = system
        self.appleMusic = appleMusic
        self.spotify = spotify
    }
}

public enum MediaSourceSelector {
    public static func select(_ s: MediaSourceSnapshot, preference: MediaSourcePreference) -> NowPlaying? {
        switch preference {
        case .appleMusic: if let m = s.appleMusic { return m }
        case .spotify: if let sp = s.spotify { return sp }
        case .automatic: break
        }
        if let sys = s.system { return sys }
        let apps = [s.appleMusic, s.spotify].compactMap { $0 }
        return apps.first { $0.isPlaying } ?? apps.first
    }
}
