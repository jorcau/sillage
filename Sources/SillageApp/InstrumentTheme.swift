import SwiftUI

/// Display colors only: changing themes never touches the audio pipeline.
enum InstrumentTheme: String, CaseIterable, Sendable {
    case mint, aurora, ember, twilight, prism, lagoon, thermal, neon, alpine

    enum SpectrumAxis { case frequency, level }

    var spectrumAxis: SpectrumAxis {
        switch self {
        case .mint, .thermal, .neon, .alpine: .level
        default: .frequency
        }
    }

    var spectrumStart: UnitPoint { spectrumAxis == .level ? .bottom : .leading }
    var spectrumEnd: UnitPoint { spectrumAxis == .level ? .top : .trailing }
    var spectrumDescription: String {
        self == .mint ? "Classic" : spectrumAxis == .level ? "By level" : "By frequency"
    }

    init(savedValue: String?) {
        if let savedValue, let theme = Self(rawValue: savedValue) { self = theme; return }
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
        case .thermal: "Thermal"
        case .neon: "Neon"
        case .alpine: "Alpine"
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
        case .thermal: [color(0x5675F0), color(0x48CBCD), color(0xBDE879), color(0xFFB35F), color(0xF06A86)]
        case .neon: [color(0x575CCE), color(0x9674EB), color(0xE47CCD), color(0xFFADB9), color(0xFFE3C0)]
        case .alpine: [color(0x277385), color(0x51B8AE), color(0x9FE3C3), color(0xDFF4E1)]
        }
    }

    var accent: Color { colors[1] }
    var peak: Color { colors[colors.count - 1] }

    /// Use one fixed coordinate space for every bar and peak marker. Level-based
    /// themes run from -90 dBFS at the bottom to 0 dBFS at the top of the plot.
    func spectrumShading(in plot: CGRect, opacity: Double) -> GraphicsContext.Shading {
        shading(from: CGPoint(x: plot.minX + plot.width * spectrumStart.x,
                              y: plot.minY + plot.height * spectrumStart.y),
                to: CGPoint(x: plot.minX + plot.width * spectrumEnd.x,
                            y: plot.minY + plot.height * spectrumEnd.y), opacity: opacity)
    }

    func shading(from start: CGPoint, to end: CGPoint, opacity: Double = 1) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors.map { $0.opacity(opacity) }), startPoint: start, endPoint: end)
    }

    private func color(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255,
              blue: Double(rgb & 255) / 255)
    }
}

private struct InstrumentThemeKey: EnvironmentKey {
    static let defaultValue = InstrumentTheme.mint
}

extension EnvironmentValues {
    var instrumentTheme: InstrumentTheme {
        get { self[InstrumentThemeKey.self] }
        set { self[InstrumentThemeKey.self] = newValue }
    }
}
