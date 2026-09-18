import SwiftUI

/// Display colors only: changing palettes never touches the audio pipeline.
enum InstrumentPalette: String, CaseIterable, Sendable {
    case mint, aurora, ember, twilight, prism, lagoon

    init(savedValue: String?) {
        if let savedValue, let palette = Self(rawValue: savedValue) { self = palette; return }
        // Preserve selections made with the initial single-color prototype.
        switch savedValue {
        case "glacier": self = .aurora
        case "amber": self = .ember
        case "violet": self = .twilight
        case "rose": self = .prism
        case "monochrome": self = .lagoon
        default: self = .mint
        }
    }

    var title: String {
        switch self {
        case .mint: "Mint (Default)"
        case .aurora: "Aurora"
        case .ember: "Ember"
        case .twilight: "Twilight"
        case .prism: "Prism"
        case .lagoon: "Lagoon"
        }
    }

    var colors: [Color] {
        switch self {
        case .mint: [SillageBrand.mint, SillageBrand.mint]
        case .aurora: [color(0x6B83FF), color(0x48D6E8), color(0x7EE3AD), color(0xE2F3A0)]
        case .ember: [color(0xEF668F), color(0xFF865B), color(0xFFC45C), color(0xFFF1AD)]
        case .twilight: [color(0x5FA2FF), color(0xA085F2), color(0xEE8ABE), color(0xFFC1A6)]
        case .prism: [color(0x7297FF), color(0x54D7EA), color(0x92E39D), color(0xF4DE77), color(0xF68DA7)]
        case .lagoon: [color(0xF0BF80), color(0x7DDCC2), color(0x54BBDA), color(0x938AEB)]
        }
    }

    var accent: Color { colors[1] }
    var peak: Color { colors[colors.count - 1] }

    func shading(from start: CGPoint, to end: CGPoint, opacity: Double = 1) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors.map { $0.opacity(opacity) }), startPoint: start, endPoint: end)
    }

    private func color(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255,
              blue: Double(rgb & 255) / 255)
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
