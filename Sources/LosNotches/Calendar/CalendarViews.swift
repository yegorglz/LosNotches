import NookCore
import SwiftUI

struct CalendarWidgetView: View {
    private var service: CalendarService { AppServices.shared.calendar }
    private var s: CalendarSettings { AppServices.shared.settings.settings.calendar }
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        if service.authorization != .authorized {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 20)).opacity(0.6)
                Text("This widget requires calendar permissions in order to show events, please enable access in settings.")
                    .font(.system(size: 10)).multilineTextAlignment(.center).opacity(0.6)
                Button("Allow access") { Task { await service.requestAccess() } }.controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                dayStrip
                let list = CalendarEventFilter.events(service.events, on: selectedDay, now: Date(), showPastToday: s.showPastEventsToday, calendar: .current)
                if list.isEmpty {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Nothing for today" : "No events")
                        .font(.system(size: 11)).opacity(0.5).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) { ForEach(list) { EventRow(event: $0) } }
                    }
                }
            }
        }
    }

    private var dayStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = (-s.daysBehind...s.daysAhead).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { d in
                        let selected = cal.isDate(d, inSameDayAs: selectedDay)
                        Button { selectedDay = d } label: {
                            VStack(spacing: 1) {
                                Text(d.formatted(.dateTime.weekday(.narrow))).font(.system(size: 8, weight: .bold)).opacity(0.5)
                                Text(d.formatted(.dateTime.day())).font(.system(size: 12, weight: .semibold))
                                Circle().fill(cal.isDateInToday(d) ? Color.red : .clear).frame(width: 3, height: 3)
                            }
                            .frame(width: 24, height: 34)
                            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.white.opacity(0.18) : .clear))
                        }
                        .buttonStyle(.plain)
                        .id(d)
                    }
                }
            }
            .onAppear { proxy.scrollTo(today, anchor: .center) }
        }
    }
}

struct EventRow: View {
    let event: EventSnapshot
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: event.colorHex)).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9)).opacity(0.55)
            }
            Spacer(minLength: 0)
            if let m = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes), event.end > Date() {
                Button("Join \(m.service.displayName)") {
                    NSWorkspace.shared.open(m.url)
                    AppServices.shared.windows.viewModels.values.forEach { $0.send(.closeRequested) }
                }
                .font(.system(size: 9, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor))
            }
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
        .onTapGesture {
            // Opens the event in Calendar.app (the URL scheme Calendar registers for EventKit events).
            if let id = event.eventIdentifier?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") {
                NSWorkspace.shared.open(url)
            }
        }
        .help("Open in Calendar")
    }
}

struct CalendarWing: View {
    let activity: LiveActivity
    let side: WingSide
    var body: some View {
        let service = AppServices.shared.calendar
        if side == .left {
            HStack(spacing: 3) {
                Circle().fill(Color(hex: service.activeEvent?.colorHex ?? "#FF3B30")).frame(width: 6, height: 6)
                Image(systemName: "calendar").font(.system(size: 12))
            }
        } else if let e = service.activeEvent {
            TimelineView(.periodic(from: .now, by: 15)) { ctx in
                Text(EventTimeText.text(for: e, now: ctx.date, showElapsed: AppServices.shared.settings.settings.calendar.showTimeElapsed))
                    .font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}
