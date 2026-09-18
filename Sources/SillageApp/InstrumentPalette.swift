import SwiftUI

/// Display colors only: changing palettes never touches the audio pipeline.
enum InstrumentPalette: String, CaseIterable, Sendable {
    case mint, amber, glacier, violet, rose, monochrome

    var title: String {
        switch self {
        case .mint: "Mint (Default)"
        case .amber: "Amber"
        case .glacier: "Glacier"
        case .violet: "Violet"
        case .rose: "Rose"
        case .monochrome: "Monochrome"
        }
    }

    var accent: Color {
        switch self {
        case .mint: SillageBrand.mint
        case .amber: Color(red: 1.00, green: 0.72, blue: 0.32)
        case .glacier: Color(red: 0.40, green: 0.76, blue: 0.98)
        case .violet: Color(red: 0.70, green: 0.60, blue: 1.00)
        case .rose: Color(red: 0.96, green: 0.57, blue: 0.70)
        case .monochrome: Color(red: 0.80, green: 0.83, blue: 0.85)
        }
    }

    var peak: Color {
        switch self {
        case .mint: SillageBrand.mint
        case .amber: Color(red: 1.00, green: 0.89, blue: 0.65)
        case .glacier: Color(red: 0.69, green: 0.92, blue: 1.00)
        case .violet: Color(red: 0.89, green: 0.80, blue: 1.00)
        case .rose: Color(red: 1.00, green: 0.80, blue: 0.86)
        case .monochrome: Color(red: 0.97, green: 0.98, blue: 1.00)
        }
    }
}

private struct InstrumentPaletteKey: EnvironmentKey {
    static let defaultValue = InstrumentPalette.mint
}

extension EnvironmentValues {
    var instrumentPalette: InstrumentPalette {
        get { self[InstrumentPaletteKey.self] }
        set { self[InstrumentPaletteKey.self] = newValue }
    }
}
