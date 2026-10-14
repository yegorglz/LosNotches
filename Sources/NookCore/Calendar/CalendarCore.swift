import Foundation

public struct EventSnapshot: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarID: String
    public var colorHex: String
    public var url: URL?
    public var location: String?
    public var notes: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, calendarID: String = "",
                colorHex: String = "#FF3B30", url: URL? = nil, location: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.colorHex = colorHex
        self.url = url
        self.location = location
        self.notes = notes
    }
}

public enum VideoConferenceService: String, CaseIterable, Sendable {
    case zoom, meet, teams, webex

    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .meet: "Meet"
        case .teams: "Teams"
        case .webex: "Webex"
        }
    }

    var pattern: String {
        switch self {
        case .zoom: #"https?://[\w.-]+\.zoom\.us/(?:j|my)/[\w?=&.%-]+"#
        case .meet: #"https?://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#
        case .teams: #"https://teams\.microsoft\.com/l/meetup-join/[\w\-%.]+/[\w:]+\?[\w=&%.]+"#
        case .webex: #"https?://[\w.-]+\.webex\.com/(?:[\w.-]+/)?(?:j\.php\?MTID=[\w]+|meet/[\w]+)(?:[?#][\w=&%.]+)?"#
        }
    }
}

public struct Meeting: Equatable, Sendable {
    public var service: VideoConferenceService
    public var url: URL
}

public enum MeetingLinkDetector {
    private static let regexes = VideoConferenceService.allCases.map { ($0, try! NSRegularExpression(pattern: $0.pattern)) }

    public static func detect(url: URL?, location: String?, notes: String?) -> Meeting? {
        for text in [url?.absoluteString, location, notes].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            let best = regexes.compactMap { service, re in re.firstMatch(in: text, range: range).map { (service, $0.range) } }
                .min { $0.1.location < $1.1.location }
            if let (service, r) = best, let found = URL(string: (text as NSString).substring(with: r)) {
                return Meeting(service: service, url: found)
            }
        }
        return nil
    }
}

public enum CalendarEventFilter {
    public static func events(_ all: [EventSnapshot], on day: Date, now: Date, showPastToday: Bool, calendar: Calendar) -> [EventSnapshot] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let isToday = calendar.isDate(day, inSameDayAs: now)
        return all
            .filter { $0.start < end && $0.end > start }
            .filter { !(isToday && !showPastToday && $0.end <= now) }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }
}

public enum CalendarActivityPolicy {
    public static func activeEvent(_ events: [EventSnapshot], now: Date, minutesBefore: Int, showWhileInEvent: Bool) -> EventSnapshot? {
        events
            .filter { !$0.isAllDay }
            .filter { $0.start.addingTimeInterval(-Double(minutesBefore) * 60) <= now && now < (showWhileInEvent ? $0.end : $0.start) }
            .min { $0.start < $1.start }
    }
}

public enum EventTimeText {
    public static func text(for e: EventSnapshot, now: Date, showElapsed: Bool) -> String {
        if now < e.start {
            let mins = Int((e.start.timeIntervalSince(now) / 60).rounded(.up))
            return mins >= 60 ? "in \(mins / 60)h \(mins % 60)m" : "in \(mins) min"
        }
        if now >= e.end { return "ended" }
        if now.timeIntervalSince(e.start) < 60 { return "now" }
        if showElapsed { return "\(Int(now.timeIntervalSince(e.start) / 60)) min in" }
        return "\(Int((e.end.timeIntervalSince(now) / 60).rounded(.up))) min left"
    }
}
