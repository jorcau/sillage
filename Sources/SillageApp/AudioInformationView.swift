import SwiftUI
import AudioAnalysis

@MainActor
private final class AudioInformationPresentation: ObservableObject {
    @Published var isPresented = false
}

/// Lives outside the animated instruments so the popover stays open during analysis.
struct AudioInformationButton: View {
    @ObservedObject var model: AppModel
    let frame: AnalysisFrame
    @StateObject private var presentation = AudioInformationPresentation()
    @Environment(\.instrumentMetrics) private var metrics

    private var hasIssues: Bool { frame.droppedFrames > 0 || frame.invalidBuffers > 0 }

    var body: some View {
        Button { presentation.isPresented.toggle() } label: {
            Image(systemName: hasIssues ? "exclamationmark.circle" : "info.circle")
                .font(.system(size: metrics.size(13)))
                .foregroundStyle(hasIssues ? InterfaceColors.amber : InterfaceColors.secondary)
                .padding(metrics.size(4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.text(hasIssues ? "Audio details · stream issues detected" : "Audio details"))
        .accessibilityLabel(model.text("Audio details"))
        .popover(isPresented: $presentation.isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(model.text("Audio details")).font(.headline)
                    Spacer()
                    Button { presentation.isPresented = false } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel(model.text("Close"))
                }
                Text(model.audioSummary(frame: frame)).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    if let format = model.streamFormat {
                        row("Sample rate", model.sampleRateText(format.sampleRate))
                        row("Channels", String(format.channels))
                        row("Sample format", model.localizer.format("%d-bit float PCM", format.bits))
                    }
                    row("FFT window", model.localizer.format("%d samples", AudioAnalyzer.fftSize))
                    if let format = model.streamFormat {
                        row("Window duration", model.localizer.format("%.1f ms", Double(AudioAnalyzer.fftSize) / format.sampleRate * 1000))
                    }
                    row("Dropped frames", String(frame.droppedFrames), warning: frame.droppedFrames > 0)
                    row("Invalid buffers", String(frame.invalidBuffers), warning: frame.invalidBuffers > 0)
                }
                Text(model.text(model.streamFormat == nil
                    ? "Start capture or a demo to see its audio format."
                    : model.mode == .demo ? "Format of the generated demo signal. No sound is played."
                    : "Format reported by macOS for the captured stream, not the original track or DAC. Silence is valid audio; waiting means no recent input has arrived."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12)).foregroundStyle(.primary)
            .padding(20).frame(width: 360).preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private func row(_ title: String, _ value: String, warning: Bool = false) -> some View {
        GridRow {
            Text(model.text(title)).foregroundStyle(.secondary)
            Text(value).monospacedDigit().foregroundStyle(warning ? InterfaceColors.amber : Color.primary)
        }
    }
}
