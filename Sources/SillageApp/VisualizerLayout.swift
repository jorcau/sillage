import SwiftUI

/// Presentation only. Every layout reads the same analysis frame and capture session.
enum VisualizerLayout: String, CaseIterable {
    case dashboard, meters, spectrum, stereo, analog, studioBlue, vintageConsole, crtWaveform, crtStereo, broadcastPPM, hifiRack

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .meters: "Meters"
        case .spectrum: "Spectrum"
        case .stereo: "Stereo"
        case .analog: "Analog VU"
        case .studioBlue: "Studio Blue"
        case .vintageConsole: "Vintage Console"
        case .crtWaveform: "CRT Oscilloscope"
        case .crtStereo: "CRT Goniometer"
        case .broadcastPPM: "Broadcast PPM"
        case .hifiRack: "Hi-Fi Rack"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .meters: "chart.bar.xaxis"
        case .spectrum: "waveform.path"
        case .stereo: "scope"
        case .analog: "gauge.with.needle"
        case .studioBlue: "gauge.with.needle"
        case .vintageConsole: "gauge.with.needle"
        case .crtWaveform: "waveform.path.ecg.rectangle"
        case .crtStereo: "scope"
        case .broadcastPPM: "chart.bar.xaxis"
        case .hifiRack: "square.stack.3d.up"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .dashboard: "1"
        case .meters: "2"
        case .spectrum: "3"
        case .stereo: "4"
        case .analog: "5"
        case .studioBlue: "6"
        case .vintageConsole: "7"
        case .crtWaveform: "8"
        case .crtStereo: "9"
        case .broadcastPPM: "0"
        case .hifiRack: "-"
        }
    }
}
