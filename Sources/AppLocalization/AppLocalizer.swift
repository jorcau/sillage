import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case system, english = "en", french = "fr"
}

/// Resolves resources explicitly, allowing a live language switch without restarting capture.
public struct AppLocalizer: Sendable {
    public let languageCode: String
    // SwiftPM's generated accessor checks beside the executable; a macOS app
    // stores resources in Contents/Resources instead. Prefer the packaged bundle.
    private static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "Sillage_AppLocalization", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
    private static let bundles: [String: Bundle] = ["en", "fr"].reduce(into: [:]) { result, code in
        if let path = resources.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
            result[code] = bundle
        }
    }

    public init(language: AppLanguage = .system, preferredLanguages: [String] = Locale.preferredLanguages) {
        if language == .system {
            languageCode = Bundle.preferredLocalizations(
                from: ["en", "fr"], forPreferences: preferredLanguages
            ).first ?? "en"
        } else {
            languageCode = language.rawValue
        }
    }

    public func text(_ key: String) -> String {
        guard let bundle = Self.bundles[languageCode] else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: languageCode), arguments: arguments)
    }
}
