import NookCore
import SwiftUI

/// Closed-notch live activity: content in the two wings beside the physical notch, plus an optional peek strip.
struct ActivityContainer: View {
    let activity: LiveActivity
    let model: NotchViewModel

    var body: some View {
        let notchWidth = model.closedScreenRect.width
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ActivityWing(activity: activity, side: .left)
                    .frame(width: NotchGeometry.activityWingWidth - 8, alignment: .leading)
                    .padding(.leading, 8)
                Spacer().frame(width: notchWidth)
                ActivityWing(activity: activity, side: .right)
                    .frame(width: NotchGeometry.activityWingWidth - 8, alignment: .trailing)
                    .padding(.trailing, 8)
            }
            .frame(height: model.closedScreenRect.height)
            if model.state.mode == .peek {
                PeekView(activity: activity)
                    .frame(height: NotchGeometry.peekHeight)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
    }
}

enum WingSide { case left, right }

struct ActivityWing: View {
    let activity: LiveActivity
    let side: WingSide

    var body: some View {
        switch activity.kind {
        case .media: MediaWing(side: side)
        case .hud: HUDWing(side: side)
        case .calendar: CalendarWing(activity: activity, side: side)
        case .timer: TimerWing(activity: activity, side: side)
        case .battery: BatteryWing(side: side)
        case .bluetooth: BluetoothWing(side: side)
        case .tray: TrayWing(side: side)
        }
    }
}

/// "Interactive activities": small controls in the peek strip.
struct PeekControls: View {
    let activity: LiveActivity
    var body: some View {
        HStack(spacing: 10) {
            switch activity.kind {
            case .media:
                let media = AppServices.shared.media
                Button { media.send(.previous) } label: { Image(systemName: "backward.fill") }
                Button { media.send(.togglePlayPause) } label: { Image(systemName: media.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill") }
                Button { media.send(.next) } label: { Image(systemName: "forward.fill") }
            case .timer where activity.id == "timer":
                let store = AppServices.shared.timers
                if let e = store.book.displayed(now: store.now) {
                    let paused = if case .paused = e.state { true } else { false }
                    Button { store.mutate { paused ? $0.resume(id: e.id, now: Date()) : $0.pause(id: e.id, now: Date()) } } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                    }
                    Button { store.mutate { $0.cancel(id: e.id) } } label: { Image(systemName: "xmark") }
                }
            default:
                EmptyView()
            }
        }
        .font(.system(size: 11))
        .buttonStyle(PressScaleStyle())
    }
}

struct PeekView: View {
    let activity: LiveActivity
    var body: some View {
        HStack(spacing: 8) {
            Text(activity.peekText ?? "")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            if AppServices.shared.settings.settings.liveActivities.interactive { PeekControls(activity: activity) }
            if activity.kind == .calendar, AppServices.shared.settings.settings.liveActivities.interactive,
               let meeting = AppServices.shared.calendar.activeMeeting {
                Button("Join \(meeting.service.displayName)") { NSWorkspace.shared.open(meeting.url) }
                    .buttonStyle(.borderedProminent).controlSize(.mini)
            }
        }
        .padding(.horizontal, 14)
    }
}
