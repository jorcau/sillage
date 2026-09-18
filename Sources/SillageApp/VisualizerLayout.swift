import SwiftUI

/// Presentation only. Every layout reads the same analysis frame and capture session.
enum VisualizerLayout: String, CaseIterable {
    case dashboard, meters, spectrum, stereo, analog

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .meters: "Meters"
        case .spectrum: "Spectrum"
        case .stereo: "Stereo"
        case .analog: "Analog VU"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .meters: "chart.bar.xaxis"
        case .spectrum: "waveform.path"
        case .stereo: "scope"
        case .analog: "gauge.with.needle"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .dashboard: "1"
        case .meters: "2"
        case .spectrum: "3"
        case .stereo: "4"
        case .analog: "5"
        }
    }
}
