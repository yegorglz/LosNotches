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

struct PeekView: View {
    let activity: LiveActivity
    var body: some View {
        HStack(spacing: 8) {
            Text(activity.peekText ?? "")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            if activity.kind == .calendar, AppServices.shared.settings.settings.liveActivities.interactive,
               let meeting = AppServices.shared.calendar.activeMeeting {
                Button("Join \(meeting.service.displayName)") { NSWorkspace.shared.open(meeting.url) }
                    .buttonStyle(.borderedProminent).controlSize(.mini)
            }
        }
        .padding(.horizontal, 14)
    }
}
