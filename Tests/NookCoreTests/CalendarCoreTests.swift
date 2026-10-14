import Foundation
import Testing
@testable import NookCore

private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
private func d(_ day: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))! }
private func ev(_ id: String, _ s: Date, _ e: Date, allDay: Bool = false) -> EventSnapshot { EventSnapshot(id: id, title: id, start: s, end: e, isAllDay: allDay) }

@Test func zoomInNotes() {
    let m = MeetingLinkDetector.detect(url: nil, location: nil, notes: "Join https://us02web.zoom.us/j/123?pwd=x now")
    #expect(m?.service == .zoom && m?.url.absoluteString == "https://us02web.zoom.us/j/123?pwd=x")
}
@Test func meetInLocation() { #expect(MeetingLinkDetector.detect(url: nil, location: "https://meet.google.com/abc-defg-hij", notes: nil)?.service == .meet) }
@Test func teamsURL() {
    let u = URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=x")
    #expect(MeetingLinkDetector.detect(url: u, location: nil, notes: nil)?.service == .teams)
}
@Test func webexURL() { #expect(MeetingLinkDetector.detect(url: nil, location: nil, notes: "https://acme.webex.com/acme/j.php?MTID=m123")?.service == .webex) }
@Test func urlFieldWinsOverNotes() {
    let m = MeetingLinkDetector.detect(url: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: "https://x.zoom.us/j/1")
    #expect(m?.service == .meet)
}
@Test func noLinkNil() { #expect(MeetingLinkDetector.detect(url: nil, location: "Room 4", notes: "agenda") == nil) }
@Test func overnightEventEndingAtMidnightNotOnNextDay() {
    let e = ev("late", d(14, 22), d(15, 0))
    #expect(CalendarEventFilter.events([e], on: d(15, 12), now: d(13, 0), showPastToday: true, calendar: cal).isEmpty)
    #expect(CalendarEventFilter.events([e], on: d(14, 12), now: d(13, 0), showPastToday: true, calendar: cal).count == 1)
}
@Test func eventSpanningMidnightOnBothDays() {
    let e = ev("x", d(14, 23), d(15, 1))
    #expect(CalendarEventFilter.events([e], on: d(14, 1), now: d(13, 0), showPastToday: true, calendar: cal).count == 1)
    #expect(CalendarEventFilter.events([e], on: d(15, 1), now: d(13, 0), showPastToday: true, calendar: cal).count == 1)
}
@Test func pastHiddenWhenFlagOff() {
    let past = ev("p", d(14, 8), d(14, 9)), later = ev("l", d(14, 15), d(14, 16))
    #expect(CalendarEventFilter.events([past, later], on: d(14, 12), now: d(14, 12), showPastToday: false, calendar: cal).map(\.id) == ["l"])
}
@Test func allDayFirstThenByStart() {
    let a = ev("a", d(14, 10), d(14, 11)), b = ev("b", d(14, 9), d(14, 10)), all = ev("all", d(14, 0), d(15, 0), allDay: true)
    #expect(CalendarEventFilter.events([a, b, all], on: d(14, 12), now: d(13, 0), showPastToday: true, calendar: cal).map(\.id) == ["all", "b", "a"])
}
@Test func activityStartsMinutesBefore() {
    let now = d(14, 10)
    #expect(CalendarActivityPolicy.activeEvent([ev("e", now + 240, now + 3600)], now: now, minutesBefore: 5, showWhileInEvent: true) != nil)
    #expect(CalendarActivityPolicy.activeEvent([ev("e", now + 360, now + 3600)], now: now, minutesBefore: 5, showWhileInEvent: true) == nil)
}
@Test func activityDuringEventOnlyWhenFlagged() {
    let now = d(14, 10), e = ev("e", now - 600, now + 600)
    #expect(CalendarActivityPolicy.activeEvent([e], now: now, minutesBefore: 5, showWhileInEvent: true) != nil)
    #expect(CalendarActivityPolicy.activeEvent([e], now: now, minutesBefore: 5, showWhileInEvent: false) == nil)
}
@Test func activityEndsAtEventEnd() {
    let now = d(14, 10)
    #expect(CalendarActivityPolicy.activeEvent([ev("e", now - 600, now)], now: now, minutesBefore: 5, showWhileInEvent: true) == nil)
}
@Test func activityIgnoresAllDay() {
    let now = d(14, 10)
    #expect(CalendarActivityPolicy.activeEvent([ev("e", d(14, 0), d(15, 0), allDay: true)], now: now, minutesBefore: 5, showWhileInEvent: true) == nil)
}
@Test func timeTexts() {
    let now = d(14, 10)
    #expect(EventTimeText.text(for: ev("e", now + 300, now + 900), now: now, showElapsed: false) == "in 5 min")
    #expect(EventTimeText.text(for: ev("e", now - 10, now + 900), now: now, showElapsed: false) == "now")
    #expect(EventTimeText.text(for: ev("e", now - 300, now + 720), now: now, showElapsed: false) == "12 min left")
    #expect(EventTimeText.text(for: ev("e", now + 5400, now + 9000), now: now, showElapsed: false) == "in 1h 30m")
    #expect(EventTimeText.text(for: ev("e", now - 300, now + 720), now: now, showElapsed: true) == "5 min in")
}
