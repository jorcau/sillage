import SwiftUI
import AudioAnalysis

struct HiFiRackView: View {
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - metrics.size(24), geometry.size.height * 2.15)
            VStack(spacing: width * 0.014) {
                HardwareCabinet(finish: .silver) {
                    HStack(spacing: width * 0.018) {
                        VStack(alignment: .leading, spacing: width * 0.01) {
                            Text("S I L L A G E").font(.system(size: width * 0.015, weight: .medium))
                            Text("STEREO\nMONITOR").font(.system(size: width * 0.010, design: .monospaced))
                            StereoPilotLights(frame: frame, labelColor: .black.opacity(0.7))
                        }.foregroundStyle(.black.opacity(0.75)).frame(width: width * 0.13)
                        AnalogChannelMeter(channel: "L", level: frame.left, style: .vintage)
                        AnalogChannelMeter(channel: "R", level: frame.right, style: .vintage)
                    }
                }.frame(height: width * 0.245)
                HardwareCabinet(finish: .graphite) {
                    HStack(spacing: width * 0.025) {
                        VStack(alignment: .leading, spacing: width * 0.01) {
                            Text(String(format: "DUAL TRACE  /  %.1f ms", frame.waveformDuration * 1_000))
                                .font(.system(size: width * 0.008, design: .monospaced)).foregroundStyle(.gray)
                            CRTScreen(frame: frame, kind: .waveform)
                        }
                        VStack(spacing: width * 0.006) {
                            Text("PHASE").font(.system(size: width * 0.008, design: .monospaced)).foregroundStyle(.gray)
                            CorrelationDial(value: frame.correlation)
                        }.frame(width: width * 0.22)
                    }
                }.frame(height: width * 0.185)
                Text("0 VU = −18 dBFS · RMS 300 ms · ±1 FS")
                    .font(.system(size: metrics.size(9), design: .monospaced)).foregroundStyle(InterfaceColors.secondary)
            }.frame(width: width).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
