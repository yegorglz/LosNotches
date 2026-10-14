import Foundation

extension KeyedDecodingContainer {
    /// Decodes a field, falling back to `fallback` when missing or invalid, so old or partial JSON always loads.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var launchAtLogin = false
    public var enableOnNonNotchScreens = true
    public var transparentHandle = false
    public var notchWidthFineTune = 0.0
    public var notchHeightFineTune = 0.0
    public var alwaysOpenOnHover = false
    public var clickToOpen = true
    public var preventCloseOnMouseLeave = false
    public var lockWhileTyping = true
    public var showInFullscreen = false
    public var showMenuBarIcon = true
    public var preferRoundButtons = false
    public var showDividers = true
    public var widgetPadding = 8.0
    public var onboardingCompleted = false

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        launchAtLogin = c.value(.launchAtLogin, d.launchAtLogin)
        enableOnNonNotchScreens = c.value(.enableOnNonNotchScreens, d.enableOnNonNotchScreens)
        transparentHandle = c.value(.transparentHandle, d.transparentHandle)
        notchWidthFineTune = c.value(.notchWidthFineTune, d.notchWidthFineTune)
        notchHeightFineTune = c.value(.notchHeightFineTune, d.notchHeightFineTune)
        alwaysOpenOnHover = c.value(.alwaysOpenOnHover, d.alwaysOpenOnHover)
        clickToOpen = c.value(.clickToOpen, d.clickToOpen)
        preventCloseOnMouseLeave = c.value(.preventCloseOnMouseLeave, d.preventCloseOnMouseLeave)
        lockWhileTyping = c.value(.lockWhileTyping, d.lockWhileTyping)
        showInFullscreen = c.value(.showInFullscreen, d.showInFullscreen)
        showMenuBarIcon = c.value(.showMenuBarIcon, d.showMenuBarIcon)
        preferRoundButtons = c.value(.preferRoundButtons, d.preferRoundButtons)
        showDividers = c.value(.showDividers, d.showDividers)
        widgetPadding = c.value(.widgetPadding, d.widgetPadding)
        onboardingCompleted = c.value(.onboardingCompleted, d.onboardingCompleted)
    }
}

public struct GestureSettings: Codable, Equatable, Sendable {
    public var allowGestures = true
    public var verticalOpenClose = true
    public var horizontalMedia = true
    public var invertMedia = false
    public var disableHaptics = false

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        allowGestures = c.value(.allowGestures, d.allowGestures)
        verticalOpenClose = c.value(.verticalOpenClose, d.verticalOpenClose)
        horizontalMedia = c.value(.horizontalMedia, d.horizontalMedia)
        invertMedia = c.value(.invertMedia, d.invertMedia)
        disableHaptics = c.value(.disableHaptics, d.disableHaptics)
    }
}

public struct LiveActivitiesSettings: Codable, Equatable, Sendable {
    public var enabled = true
    public var quickPeek = true
    public var showSongChange = true
    public var unhideAutomatically = true
    public var interactive = true
    public var inactivityTimeoutSeconds = 5.0
    public var enabledKinds = Set(LiveActivityKind.allCases)
    public var visibleInFullscreen: Set<LiveActivityKind> = [.hud, .timer]
    public var hudReplacement = false
    public var hudMonochrome = false
    public var lowBatteryThreshold = 20

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        enabled = c.value(.enabled, d.enabled)
        quickPeek = c.value(.quickPeek, d.quickPeek)
        showSongChange = c.value(.showSongChange, d.showSongChange)
        unhideAutomatically = c.value(.unhideAutomatically, d.unhideAutomatically)
        interactive = c.value(.interactive, d.interactive)
        inactivityTimeoutSeconds = c.value(.inactivityTimeoutSeconds, d.inactivityTimeoutSeconds)
        enabledKinds = c.value(.enabledKinds, d.enabledKinds)
        visibleInFullscreen = c.value(.visibleInFullscreen, d.visibleInFullscreen)
        hudReplacement = c.value(.hudReplacement, d.hudReplacement)
        hudMonochrome = c.value(.hudMonochrome, d.hudMonochrome)
        lowBatteryThreshold = c.value(.lowBatteryThreshold, d.lowBatteryThreshold)
    }
}

public struct MediaSettings: Codable, Equatable, Sendable {
    public var preferredSource = MediaSourcePreference.automatic
    public var effect = MediaEffect.waves
    public var coloredEffects = true
    public var albumCornerRadius = 8.0

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        preferredSource = c.value(.preferredSource, d.preferredSource)
        effect = c.value(.effect, d.effect)
        coloredEffects = c.value(.coloredEffects, d.coloredEffects)
        albumCornerRadius = c.value(.albumCornerRadius, d.albumCornerRadius)
    }
}

public struct CalendarSettings: Codable, Equatable, Sendable {
    /// Empty means all calendars.
    public var selectedCalendarIDs: [String] = []
    public var daysBehind = 1
    public var daysAhead = 5
    public var showPastEventsToday = true
    public var activityMinutesBefore = 5
    public var showWhileInEvent = true
    public var showTimeElapsed = false

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self()
        selectedCalendarIDs = c.value(.selectedCalendarIDs, d.selectedCalendarIDs)
        daysBehind = c.value(.daysBehind, d.daysBehind)
        daysAhead = c.value(.daysAhead, d.daysAhead)
        showPastEventsToday = c.value(.showPastEventsToday, d.showPastEventsToday)
        activityMinutesBefore = c.value(.activityMinutesBefore, d.activityMinutesBefore)
        showWhileInEvent = c.value(.showWhileInEvent, d.showWhileInEvent)
        showTimeElapsed = c.value(.showTimeElapsed, d.showTimeElapsed)
    }
}

public struct NookLayoutSettings: Codable, Equatable, Sendable {
    public var widgets: [WidgetPlacement] = [
        .init(kind: .media, widthCells: 4), .init(kind: .calendar, widthCells: 4), .init(kind: .todos, widthCells: 4),
    ]

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        widgets = c.value(.widgets, Self().widgets)
    }
}

public struct MirrorSettings: Codable, Equatable, Sendable {
    public var deviceUniqueID: String? = nil
    public var mirrored = true

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceUniqueID = c.value(.deviceUniqueID, nil as String?)
        mirrored = c.value(.mirrored, true)
    }
}

public struct WidgetContentSettings: Codable, Equatable, Sendable {
    public var quickAppPaths: [String] = []
    public var shortcutNames: [String] = []

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quickAppPaths = c.value(.quickAppPaths, [String]())
        shortcutNames = c.value(.shortcutNames, [String]())
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var general = GeneralSettings()
    public var gestures = GestureSettings()
    public var liveActivities = LiveActivitiesSettings()
    public var media = MediaSettings()
    public var calendar = CalendarSettings()
    public var nook = NookLayoutSettings()
    public var mirror = MirrorSettings()
    public var content = WidgetContentSettings()

    public static let `default` = AppSettings()

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        general = c.value(.general, GeneralSettings())
        gestures = c.value(.gestures, GestureSettings())
        liveActivities = c.value(.liveActivities, LiveActivitiesSettings())
        media = c.value(.media, MediaSettings())
        calendar = c.value(.calendar, CalendarSettings())
        nook = c.value(.nook, NookLayoutSettings())
        mirror = c.value(.mirror, MirrorSettings())
        content = c.value(.content, WidgetContentSettings())
    }
}
