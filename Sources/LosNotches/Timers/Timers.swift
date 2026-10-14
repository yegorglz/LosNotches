import AppKit
import NookCore
import SwiftUI

@MainActor
@Observable
final class TimersStore {
    private(set) var book: TimerBook
    private(set) var now = Date()
    @ObservationIgnored private let store: JSONFileStore<TimerBook>
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private var timer: Timer?

    init(directory: URL, activities: LiveActivityCenter) {
        store = JSONFileStore(url: directory.appendingPathComponent("timers.json")) { TimerBook() }
        book = store.load()
        self.activities = activities
    }

    func start() {
        // Timers that ended while the app was closed are finished silently.
        _ = book.collectFinished(now: Date())
        book.entries.removeAll { $0.state == .finished }
        save()
        tick()
    }

    func mutate(_ f: (inout TimerBook) -> Void) {
        f(&book)
        save()
        tick()
    }

    private func save() { try? store.save(book) }

    private func tick() {
        now = Date()
        for done in book.collectFinished(now: now) {
            NSSound(named: "Glass")?.play()
            let text = done.label.isEmpty ? "Timer done" : "\(done.label) done"
            activities.upsert(LiveActivity(id: "timer-done:\(done.id)", kind: .timer, revision: 1, expiresAt: now + 8, peekText: text))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.activities.requestPeek(id: "timer-done:\(done.id)", seconds: 4) }
            save()
        }
        if let soonest = book.soonestRunning(now: now) {
            activities.upsert(LiveActivity(id: "timer", kind: .timer, revision: soonest.id.hashValue, peekText: soonest.label.isEmpty ? nil : soonest.label))
        } else {
            activities.remove(id: "timer")
        }
        let running = book.soonestRunning(now: now) != nil
        if running, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        } else if !running {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct TimerWidgetView: View {
    private var store: TimersStore { AppServices.shared.timers }
    @State private var h = 0
    @State private var m = 5
    @State private var s = 0

    var body: some View {
        let running = store.book.entries.filter { $0.state != .finished }
        VStack(spacing: 6) {
            HStack { WidgetHeader(title: "Timers"); Spacer() }
            if running.isEmpty {
                HStack(spacing: 2) {
                    WheelPicker(value: $h, range: 0...23, unit: "h")
                    WheelPicker(value: $m, range: 0...59, unit: "m")
                    WheelPicker(value: $s, range: 0...59, unit: "s")
                }
                .frame(height: 66)
                HStack(spacing: 4) {
                    ForEach(TimerWheel.presets, id: \.self) { p in
                        Button("\(Int(p / 60))m") { (h, m, s) = TimerWheel.components(p) }
                            .font(.system(size: 9, weight: .semibold)).buttonStyle(NookButtonStyle())
                    }
                    Spacer(minLength: 0)
                    Button { store.mutate { $0.start(duration: TimerWheel.seconds(h: h, m: m, s: s), label: "", now: Date()) } } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(NookButtonStyle())
                    .disabled(h + m + s == 0)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) { ForEach(running) { TimerRow(entry: $0) } }
                }
                Button { store.mutate { $0.start(duration: TimerWheel.seconds(h: h, m: m, s: s), label: "", now: Date()) } } label: {
                    Label("Another \(DurationText.format(TimerWheel.seconds(h: h, m: m, s: s)))", systemImage: "plus")
                }
                .font(.system(size: 9)).buttonStyle(NookButtonStyle())
                .disabled(h + m + s == 0)
            }
        }
    }
}

struct TimerRow: View {
    let entry: TimerEntry
    private var store: TimersStore { AppServices.shared.timers }

    var body: some View {
        let remaining = store.book.remaining(id: entry.id, now: store.now)
        let paused = if case .paused = entry.state { true } else { false }
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 3)
                Circle().trim(from: 0, to: entry.duration > 0 ? remaining / entry.duration : 0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            .animation(.linear(duration: 1), value: remaining)
            Text(DurationText.format(remaining)).font(.system(size: 15, weight: .semibold).monospacedDigit())
            Spacer(minLength: 0)
            Button { store.mutate { paused ? $0.resume(id: entry.id, now: Date()) : $0.pause(id: entry.id, now: Date()) } } label: {
                Image(systemName: paused ? "play.fill" : "pause.fill")
            }
            Button { store.mutate { $0.cancel(id: entry.id) } } label: { Image(systemName: "xmark") }
        }
        .font(.system(size: 10))
        .buttonStyle(NookButtonStyle())
    }
}

/// Vertical snapping number wheel with haptic ticks.
struct WheelPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    @State private var position: Int?

    var body: some View {
        HStack(spacing: 1) {
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(range, id: \.self) { n in
                        Text(String(format: "%02d", n))
                            .font(.system(size: 18, weight: .semibold).monospacedDigit())
                            .opacity(n == value ? 1 : 0.3)
                            .frame(height: 22)
                            .id(n)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, 22, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .frame(width: 30, height: 66)
            .mask(LinearGradient(colors: [.clear, .white, .clear], startPoint: .top, endPoint: .bottom))
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(value, anchor: .center)
                    position = value
                }
            }
            .onChange(of: position) { _, p in
                guard let p, p != value else { return }
                value = p
                if !AppServices.shared.settings.settings.gestures.disableHaptics {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            .onChange(of: value) { _, v in if position != v { withAnimation { proxy.scrollTo(v, anchor: .center) } } }
            }
            Text(unit).font(.system(size: 9, weight: .bold)).opacity(0.4)
        }
    }
}

struct TimerWing: View {
    let activity: LiveActivity
    let side: WingSide
    var body: some View {
        let store = AppServices.shared.timers
        if side == .left {
            Image(systemName: activity.id.hasPrefix("timer-done") ? "bell.fill" : "timer").font(.system(size: 12)).foregroundStyle(.orange)
        } else if let e = store.book.soonestRunning(now: store.now) {
            Text(DurationText.format(store.book.remaining(id: e.id, now: store.now)))
                .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.orange)
        } else {
            Text("Done").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
        }
    }
}
