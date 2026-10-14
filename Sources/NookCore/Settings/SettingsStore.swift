import Foundation
import Observation

@Observable
public final class SettingsStore {
    public var settings: AppSettings {
        didSet { if settings != oldValue { save() } }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "losnotches.settings.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    public func reset() { settings = .default }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
    }
}
