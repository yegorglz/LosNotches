import AppKit
import EventKit
import NookCore

@MainActor
@Observable
final class CalendarService {
    enum Authorization { case notDetermined, denied, authorized }

    private(set) var authorization: Authorization = .notDetermined
    private(set) var events: [EventSnapshot] = []
    private(set) var calendars: [(id: String, title: String, colorHex: String)] = []
    private(set) var activeMeeting: Meeting?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let activities: LiveActivityCenter
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var activityID: String?

    init(settings: SettingsStore, activities: LiveActivityCenter) {
        self.settings = settings
        self.activities = activities
    }

    func start() {
        updateAuthorization()
        let nc = NotificationCenter.default
        nc.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        nc.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        observeChanges({ [settings] in _ = settings.settings.calendar }) { [weak self] in self?.refresh() }
        refresh()
    }

    func requestAccess() async {
        if EKEventStore.authorizationStatus(for: .event) == .denied {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            return
        }
        _ = try? await store.requestFullAccessToEvents()
        updateAuthorization()
        refresh()
    }

    private func updateAuthorization() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: authorization = .authorized
        case .notDetermined: authorization = .notDetermined
        default: authorization = .denied
        }
    }

    func refresh() {
        updateAuthorization()
        guard authorization == .authorized else { events = []; calendars = []; updateActivity(); return }
        let all = store.calendars(for: .event)
        calendars = all.map { ($0.calendarIdentifier, $0.title, Self.hex($0.cgColor)) }
        let s = settings.settings.calendar
        let selected = s.selectedCalendarIDs.isEmpty ? nil : all.filter { s.selectedCalendarIDs.contains($0.calendarIdentifier) }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -s.daysBehind, to: today)!
        let end = cal.date(byAdding: .day, value: s.daysAhead + 1, to: today)!
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: selected)
        events = store.events(matching: pred).map { e in
            EventSnapshot(id: "\(e.eventIdentifier ?? UUID().uuidString)-\(Int(e.startDate.timeIntervalSince1970))",
                          title: e.title ?? "Untitled", start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                          calendarID: e.calendar.calendarIdentifier, colorHex: Self.hex(e.calendar.cgColor),
                          url: e.url, location: e.location, notes: e.notes, eventIdentifier: e.eventIdentifier)
        }
        updateActivity()
    }

    private func updateActivity() {
        let s = settings.settings.calendar
        let active = CalendarActivityPolicy.activeEvent(events, now: Date(), minutesBefore: s.activityMinutesBefore, showWhileInEvent: s.showWhileInEvent)
        let id = active.map { "calendar:\($0.id)" }
        if let old = activityID, old != id { activities.remove(id: old) }
        activityID = id
        activeMeeting = active.flatMap { MeetingLinkDetector.detect(url: $0.url, location: $0.location, notes: $0.notes) }
        if let active, let id { activities.upsert(LiveActivity(id: id, kind: .calendar, expiresAt: active.end, peekText: active.title)) }
        // Re-evaluate every 30 s only while something happens within the next day.
        let soon = events.contains { !$0.isAllDay && $0.end > Date() && $0.start < Date() + 86_400 }
        if soon, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateActivity() } }
        } else if !soon {
            timer?.invalidate()
            timer = nil
        }
    }

    var activeEvent: EventSnapshot? {
        activityID.flatMap { id in events.first { "calendar:\($0.id)" == id } }
    }

    private static func hex(_ c: CGColor?) -> String {
        guard let c = c.flatMap({ NSColor(cgColor: $0)?.usingColorSpace(.sRGB) }) else { return "#FF3B30" }
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
