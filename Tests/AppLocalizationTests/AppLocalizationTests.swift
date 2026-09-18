import Foundation
import Testing
@testable import AppLocalization

@Test func explicitLanguageOverridesSystemPreference() {
    let english = AppLocalizer(language: .english, preferredLanguages: ["fr-FR"])
    let french = AppLocalizer(language: .french, preferredLanguages: ["en-US"])
    #expect(english.text("Settings") == "Settings")
    #expect(french.text("Settings") != "Settings")
    #expect(french.text("Settings") != french.text("Language"))
}

@Test func systemLanguageResolvesRegionsAndFallsBackToEnglish() {
    #expect(AppLocalizer(preferredLanguages: ["fr-CA"]).languageCode == "fr")
    #expect(AppLocalizer(preferredLanguages: ["de-DE", "fr-FR"]).languageCode == "fr")
    #expect(AppLocalizer(preferredLanguages: ["ja-JP"]).languageCode == "en")
    #expect(AppLocalizer(preferredLanguages: []).languageCode == "en")
}

@Test func missingTranslationKeepsReadableSourceText() {
    #expect(AppLocalizer(language: .french).text("New source text") == "New source text")
}

@Test func localizedFormatPreservesMeasurementsAndErrorDetails() {
    let french = AppLocalizer(language: .french)
    let level = french.format("%.1f kHz · STEREO", 48.0)
    #expect(level.contains("48,0"))
    let error = french.format("%@: Core Audio error %d. Check audio capture permission in System Settings → Privacy & Security.", "Operation", Int32(-123))
    #expect(error.contains("Operation"))
    #expect(error.contains("-123"))
}
