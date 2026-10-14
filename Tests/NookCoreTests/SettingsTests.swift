import Foundation
import Testing
@testable import NookCore

private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

@Test func emptyJSONDecodesToDefaults() throws {
    #expect(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)) == .default)
}

@Test func partialSectionKeepsOtherDefaults() throws {
    let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"general":{"alwaysOpenOnHover":true}}"#.utf8))
    var expected = AppSettings.default
    expected.general.alwaysOpenOnHover = true
    #expect(s == expected)
}

@Test func settingsPersistAcrossStoreInstances() {
    let d = freshDefaults()
    SettingsStore(defaults: d).settings.general.clickToOpen = false
    #expect(SettingsStore(defaults: d).settings.general.clickToOpen == false)
}

@Test func corruptDefaultsDataFallsBackToDefault() {
    let d = freshDefaults()
    d.set(Data("x".utf8), forKey: "losnotches.settings.v1")
    #expect(SettingsStore(defaults: d).settings == .default)
}

@Test func resetRestoresDefaults() {
    let store = SettingsStore(defaults: freshDefaults())
    store.settings.media.coloredEffects = false
    store.reset()
    #expect(store.settings == .default)
}
