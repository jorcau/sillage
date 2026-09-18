import SwiftUI
import AudioAnalysis

struct DashboardInstruments: View {
    @ObservedObject var model: AppModel
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics

    var body: some View {
        Group {
            switch model.layout {
            case .dashboard:
                VStack(spacing: metrics.size(26)) {
                    GeometryReader { geometry in
                        HStack(spacing: metrics.size(26)) {
                            spectrum.frame(width: metrics.snap((geometry.size.width - metrics.size(26)) * 0.70))
                            stereo
                        }
                    }
                    compactLevels
                }
            case .meters:
                InstrumentPanel(title: model.text("LEVELS"), detail: model.text("RMS · SAMPLE PEAK · dBFS")) {
                    FocusedLevelView(frame: frame, showPeaks: model.showPeaks)
                }
            case .spectrum:
                spectrum
            case .stereo:
                stereo
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var spectrum: some View {
        InstrumentPanel(title: model.text("SPECTRUM"), detail: "20 Hz — 20 kHz") {
            SpectrumView(frame: frame, showPeaks: model.showPeaks)
        }
    }

    private var stereo: some View {
        InstrumentPanel(title: model.text("STEREO IMAGE"), detail: "L / R") {
            PhaseView(frame: frame)
        }
    }

    private var compactLevels: some View {
        InstrumentPanel(title: model.text("LEVELS"), detail: model.text("RMS · SAMPLE PEAK · dBFS")) {
            LevelView(frame: frame, showPeaks: model.showPeaks).frame(height: metrics.size(120))
        }
    }
}
