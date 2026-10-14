import Foundation

public enum LiveActivityKind: String, Codable, CaseIterable, Sendable {
    case hud, battery, bluetooth, calendar, timer, media, tray

    public var priority: Int {
        switch self {
        case .hud: 100
        case .battery: 80
        case .bluetooth: 70
        case .calendar: 60
        case .timer: 50
        case .media: 40
        case .tray: 30
        }
    }

    public var title: String {
        switch self {
        case .hud: "Volume & Brightness"
        case .battery: "Battery"
        case .bluetooth: "Bluetooth"
        case .calendar: "Calendar"
        case .timer: "Timer"
        case .media: "Media"
        case .tray: "Tray"
        }
    }
}

public enum WidgetKind: String, Codable, CaseIterable, Sendable {
    case media, calendar, notes, todos, timer, mirror, shortcuts, quickApps, tray

    public var minCells: Int {
        switch self {
        case .media, .calendar, .notes, .todos: 3
        case .timer, .mirror, .shortcuts, .quickApps, .tray: 2
        }
    }

    public var title: String {
        switch self {
        case .media: "Media Player"
        case .calendar: "Calendar"
        case .notes: "Notes"
        case .todos: "To-dos"
        case .timer: "Timers"
        case .mirror: "Mirror"
        case .shortcuts: "Shortcuts"
        case .quickApps: "Quick Apps"
        case .tray: "Files Tray"
        }
    }
}

public enum MediaSourcePreference: String, Codable, CaseIterable, Sendable {
    case automatic, appleMusic, spotify

    public var title: String {
        switch self {
        case .automatic: "Automatic (any app)"
        case .appleMusic: "Music"
        case .spotify: "Spotify"
        }
    }
}

public enum MediaEffect: String, Codable, CaseIterable, Sendable {
    case waves, none
}

public struct WidgetPlacement: Codable, Equatable, Sendable {
    public var kind: WidgetKind
    public var widthCells: Int
    public init(kind: WidgetKind, widthCells: Int) {
        self.kind = kind
        self.widthCells = widthCells
    }
}
