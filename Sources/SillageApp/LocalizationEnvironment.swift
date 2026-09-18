import SwiftUI
import AppLocalization

private struct AppLocalizerKey: EnvironmentKey {
    static let defaultValue = AppLocalizer()
}

extension EnvironmentValues {
    var appLocalizer: AppLocalizer {
        get { self[AppLocalizerKey.self] }
        set { self[AppLocalizerKey.self] = newValue }
    }
}
