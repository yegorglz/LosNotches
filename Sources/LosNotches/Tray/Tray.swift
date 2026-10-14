import AppKit
import NookCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class TrayService {
    private(set) var items: [TrayItem] = []
    @ObservationIgnored private let store: TrayStore
    @ObservationIgnored private let activities: LiveActivityCenter

    init(directory: URL, activities: LiveActivityCenter) {
        store = TrayStore(directory: directory.appendingPathComponent("Tray", isDirectory: true))
        self.activities = activities
    }

    func start() {
        items = store.items
        updateActivity()
    }

    func url(for item: TrayItem) -> URL? { store.url(for: item.id) }

    func add(_ urls: [URL], move: Bool) {
        _ = try? store.add(urls, move: move)
        sync()
    }

    func remove(_ item: TrayItem) {
        store.remove(id: item.id)
        sync()
    }

    func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: urls)
    }

    /// ⌘V: file URLs, else an image (PNG), else text.
    func paste(from pb: NSPasteboard = .general) {
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            add(urls, move: false)
            return
        }
        let stamp = Date().formatted(.verbatim("\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)).\(minute: .twoDigits).\(second: .twoDigits)", timeZone: .current, calendar: .current))
        if let image = NSImage(pasteboard: pb), let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            _ = try? store.addData(png, suggestedName: "Pasted \(stamp).png")
        } else if let text = pb.string(forType: .string) {
            _ = try? store.addData(Data(text.utf8), suggestedName: "Pasted \(stamp).txt")
        }
        sync()
    }

    private func sync() {
        store.pruneMissing()
        items = store.items
        updateActivity()
    }

    private func updateActivity() {
        if items.isEmpty { activities.remove(id: "tray") }
        else { activities.upsert(LiveActivity(id: "tray", kind: .tray, revision: items.count, peekText: "\(items.count) file\(items.count == 1 ? "" : "s") in the tray")) }
    }
}

struct TrayWidgetView: View {
    let model: NotchViewModel
    private var tray: TrayService { AppServices.shared.tray }
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WidgetHeader(title: "Tray")
                Spacer()
                if tray.items.count > 4 {
                    Button(expanded ? "Less" : "+\(tray.items.count - 4)") { withAnimation(.nook) { expanded.toggle() } }
                        .font(.system(size: 9, weight: .semibold)).buttonStyle(NookButtonStyle())
                }
            }
            if tray.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 20)).opacity(0.4)
                    Text("Drop files here").font(.system(size: 10)).opacity(0.4)
                    Text("⌘V to paste").font(.system(size: 9)).opacity(0.3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 4)], spacing: 6) {
                        ForEach(expanded ? tray.items : Array(tray.items.prefix(4))) { TrayFileView(item: $0) }
                    }
                }
            }
        }
        .background(PasteCatcher { tray.paste() })
    }
}

struct TrayFileView: View {
    let item: TrayItem
    private var tray: TrayService { AppServices.shared.tray }

    var body: some View {
        let url = tray.url(for: item)
        VStack(spacing: 2) {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage())
                .resizable().frame(width: 36, height: 36)
            Text(url?.lastPathComponent ?? item.displayName).font(.system(size: 8)).lineLimit(1).truncationMode(.middle)
        }
        .frame(width: 52)
        .contentShape(Rectangle())
        .onDrag { url.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
        .onTapGesture(count: 2) { if let url { NSWorkspace.shared.open(url) } }
        .contextMenu {
            if let url {
                Button("Open") { NSWorkspace.shared.open(url) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Send via AirDrop") { tray.airDrop([url]) }
            }
            Divider()
            Button("Remove from tray", role: .destructive) { tray.remove(item) }
        }
    }
}

/// Invisible ⌘V button active while the Nook is key.
struct PasteCatcher: View {
    let action: () -> Void
    var body: some View {
        Button("", action: action).keyboardShortcut("v", modifiers: .command).opacity(0).allowsHitTesting(false)
    }
}

struct DropTargetsView: View {
    let model: NotchViewModel

    var body: some View {
        HStack(spacing: 14) {
            target(.tray, "Tray", "tray.and.arrow.down.fill", hint: "⌥ to move")
            target(.airdrop, "AirDrop", "dot.radiowaves.left.and.right", hint: "Send nearby")
        }
        .padding(.top, max(model.closedScreenRect.height, 28) + 6)
        .padding(.horizontal, 24).padding(.bottom, 18)
        .foregroundStyle(.white)
        .coordinateSpace(name: "drop")
        .onPreferenceChange(DropFramesKey.self) { model.dropTargetFrames = $0 }
    }

    private func target(_ t: DropTarget, _ title: String, _ symbol: String, hint: String) -> some View {
        let hot = model.hoveredDropTarget == t
        return VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 26)).symbolEffect(.bounce, value: hot)
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(hint).font(.system(size: 9)).opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            .foregroundStyle(.white.opacity(hot ? 0.8 : 0.25)))
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(hot ? 0.12 : 0.03)))
        .scaleEffect(hot ? 1.03 : 1)
        .animation(.nook, value: hot)
        .background(GeometryReader { g in
            Color.clear.preference(key: DropFramesKey.self, value: [t: g.frame(in: .named("root"))])
        })
    }
}

struct DropFramesKey: PreferenceKey {
    static var defaultValue: [DropTarget: CGRect] = [:]
    static func reduce(value: inout [DropTarget: CGRect], nextValue: () -> [DropTarget: CGRect]) { value.merge(nextValue()) { $1 } }
}

struct TrayWing: View {
    let side: WingSide
    var body: some View {
        if side == .left { Image(systemName: "tray.full.fill").font(.system(size: 12)) }
        else { Text("\(AppServices.shared.tray.items.count)").font(.system(size: 12, weight: .semibold).monospacedDigit()) }
    }
}
