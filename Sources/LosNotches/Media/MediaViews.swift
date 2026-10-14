import NookCore
import SwiftUI

struct MediaWidgetView: View {
    private var media: MediaController { AppServices.shared.media }
    private var s: MediaSettings { AppServices.shared.settings.settings.media }

    var body: some View {
        if let n = media.nowPlaying {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    AlbumArt(image: media.artwork, size: 64, radius: s.albumCornerRadius)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.title.isEmpty ? "Unknown Title" : n.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(n.artist.isEmpty ? "Unknown Artist" : n.artist).font(.system(size: 11)).opacity(0.6).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if media.availableSources.count > 1 { SourceMenu() }
                    if n.isPlaying, s.effect == .waves { WaveBars(playing: true, tint: s.coloredEffects ? media.tint : nil).frame(width: 18, height: 14) }
                }
                MediaScrubber(nowPlaying: n)
                HStack(spacing: 22) {
                    Spacer()
                    controlButton("backward.fill") { media.send(.previous) }
                    controlButton(n.isPlaying ? "pause.fill" : "play.fill", size: 20) { media.send(.togglePlayPause) }
                    controlButton("forward.fill") { media.send(.next) }
                    Spacer()
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.note").font(.system(size: 22)).opacity(0.5)
                Text("No app seems to be running").font(.system(size: 11)).opacity(0.5)
                Text("Wanna open one?").font(.system(size: 10)).opacity(0.35)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat = 15, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: size)).frame(width: 28, height: 28).contentShape(Rectangle()) }
            .buttonStyle(PressScaleStyle())
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.85 : 1).animation(.nook, value: configuration.isPressed)
    }
}

struct SourceMenu: View {
    var body: some View {
        let store = AppServices.shared.settings
        Menu {
            ForEach(AppServices.shared.media.availableSources, id: \.self) { src in
                Button { store.settings.media.preferredSource = src } label: {
                    if store.settings.media.preferredSource == src { Label(src.title, systemImage: "checkmark") } else { Text(src.title) }
                }
            }
        } label: { Image(systemName: "rectangle.2.swap").font(.system(size: 11)) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }
}

struct AlbumArt: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fill) }
            else { ZStack { Color.white.opacity(0.1); Image(systemName: "music.note").opacity(0.5) } }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius * size / 56, style: .continuous))
    }
}

struct MediaScrubber: View {
    let nowPlaying: NowPlaying
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: nowPlaying.isPlaying ? 1 : 3600)) { ctx in
            let elapsed = nowPlaying.elapsed(at: ctx.date)
            let duration = max(nowPlaying.duration, 0.001)
            let fraction = dragFraction ?? min(1, elapsed / duration)
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(.white.opacity(0.85)).frame(width: max(4, geo.size.width * fraction))
                    }
                    .frame(height: dragFraction == nil ? 4 : 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in dragFraction = min(1, max(0, v.location.x / geo.size.width)) }
                        .onEnded { _ in
                            if let f = dragFraction { AppServices.shared.media.seek(to: f * nowPlaying.duration) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dragFraction = nil }
                        })
                    .animation(.nook, value: dragFraction == nil)
                }
                .frame(height: 10)
                HStack {
                    Text(DurationText.format(fraction * nowPlaying.duration))
                    Spacer()
                    Text("-" + DurationText.format(nowPlaying.duration - fraction * nowPlaying.duration))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit()).opacity(0.5)
            }
            .opacity(nowPlaying.duration > 0 ? 1 : 0.3)
            .disabled(nowPlaying.duration <= 0)
        }
    }
}

struct WaveBars: View {
    let playing: Bool
    let tint: Color?
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(tint ?? .white)
                        .frame(width: 3)
                        .scaleEffect(y: playing ? 0.35 + 0.65 * abs(sin(t * (3.1 + Double(i) * 0.9) + Double(i))) : 0.3, anchor: .center)
                }
            }
        }
    }
}

struct MediaWing: View {
    let side: WingSide
    private var media: MediaController { AppServices.shared.media }
    var body: some View {
        let s = AppServices.shared.settings.settings.media
        if side == .left {
            AlbumArt(image: media.artwork, size: 22, radius: s.albumCornerRadius)
        } else if s.effect == .waves {
            WaveBars(playing: media.nowPlaying?.isPlaying ?? false, tint: s.coloredEffects ? media.tint : nil).frame(width: 20, height: 14)
        } else {
            Image(systemName: media.nowPlaying?.isPlaying == true ? "play.fill" : "pause.fill").font(.system(size: 11))
        }
    }
}
