import SwiftUI
import AudioAnalysis

enum Palette {
    static let mint = SillageBrand.mint
    static let secondary = Color(white: 0.49)
    static let line = Color(white: 0.13)
    static let amber = Color(red: 0.88, green: 0.69, blue: 0.43)
}

struct Dashboard: View {
    @ObservedObject var model: AppModel
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        GeometryReader { viewport in
            let scale = min(2.5, max(1, min(viewport.size.width / 1500, viewport.size.height / 820)))
            DashboardSurface(model: model)
                .environment(\.instrumentMetrics, InstrumentMetrics(scale: scale, displayScale: displayScale))
        }.background(Color.black)
    }
}

private struct DashboardSurface: View {
    @ObservedObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.instrumentMetrics) private var metrics
    private func m(_ value: CGFloat) -> CGFloat { metrics.size(value) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Double(model.targetFPS), paused: scenePhase == .background || (model.mode == .idle && !model.busy))) { timeline in
            let frame = model.store.read()
            let time = timeline.date.timeIntervalSinceReferenceDate
            // Whole backing pixels prevent interpolation blur during OLED pixel shifting.
            let driftX = model.protectOLED ? metrics.snap(sin(time / 41) * 2) : 0
            let driftY = model.protectOLED ? metrics.snap(cos(time / 53) * 2) : 0
            let isSilent = max(frame.left.peakDB, frame.right.peakDB) < -75
            VStack(spacing: m(26)) {
                header(frame: frame)
                if let error = model.displayedError {
                    HStack {
                        Text(error).font(.system(size: m(12)))
                        Spacer()
                        Button(model.text("macOS Settings")) { model.openPrivacy() }
                    }.foregroundStyle(Palette.amber)
                }
                GeometryReader { geometry in
                    HStack(spacing: m(26)) {
                        InstrumentPanel(title: model.text("SPECTRUM"), detail: "20 Hz — 20 kHz") {
                            SpectrumView(frame: frame, showPeaks: model.showPeaks)
                        }.frame(width: metrics.snap((geometry.size.width - m(26)) * 0.70))
                        InstrumentPanel(title: model.text("STEREO IMAGE"), detail: "L / R") {
                            PhaseView(frame: frame)
                        }
                    }
                }
                InstrumentPanel(title: model.text("LEVELS"), detail: model.text("RMS · SAMPLE PEAK · dBFS")) {
                    LevelView(frame: frame, showPeaks: model.showPeaks)
                        .frame(height: m(120))
                }
                footer(frame: frame)
            }
            .padding(.horizontal, m(38)).padding(.top, m(48)).padding(.bottom, m(26))
            .opacity(model.brightness * ((isSilent && model.protectOLED && model.mode != .idle) ? 0.72 : 1))
            .offset(x: driftX, y: driftY)
            .background(Color.black)
            .onChange(of: timeline.date) { _, date in
                if model.displayMetrics.tick(date) { writeDiagnostics(frame: frame) }
            }
        }
        .background(Color.black)
    }
    private func header(frame: AnalysisFrame) -> some View {
        HStack(alignment: .center, spacing: m(20)) {
            VStack(alignment: .leading, spacing: m(7)) {
                HStack(spacing: m(10)) {
                    SillageMark().stroke(Palette.mint, style: StrokeStyle(lineWidth: m(1.2), lineCap: .round, lineJoin: .round))
                        .frame(width: m(28), height: m(23)).accessibilityHidden(true)
                    Text("SILLAGE").font(.system(size: m(23), weight: .medium, design: .rounded)).tracking(m(6))
                }
                Text(model.text("S O U N D ,  I N  L I G H T")).font(.system(size: m(9), weight: .medium)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: m(15))
            VStack(alignment: .trailing, spacing: m(6)) {
                HStack(spacing: m(7)) {
                    Circle().fill(model.mode == .system ? Palette.mint : Palette.secondary).frame(width: m(5), height: m(5))
                    Text(model.status(frame: frame)).font(.system(size: m(11), weight: .medium))
                }
                Text(model.displayedDeviceName).font(.system(size: m(10))).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            SettingsLink {
                Image(systemName: "gearshape").font(.system(size: m(14)))
            }.buttonStyle(.plain)
                .help(model.text("Settings") + " · ⌘,")
                .accessibilityLabel(model.text("Settings"))
            Button { Task { if model.mode == .system { await model.stop() } else { await model.startSystem() } } } label: {
                Label(model.text(model.busy ? "Connecting…" : model.mode == .system ? "Pause" : "Listen"), systemImage: model.mode == .system ? "pause.fill" : "play.fill")
                    .font(.system(size: m(11), weight: .medium)).padding(.horizontal, m(13)).padding(.vertical, m(10))
            }.buttonStyle(.plain).background(Palette.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: m(6)))
                .foregroundStyle(Palette.mint).disabled(model.busy)
            Button { model.toggleFullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: m(13))) }
                .buttonStyle(.plain).help(model.text("Full Screen") + " · ⌃⌘F")
                .accessibilityLabel(model.text("Full Screen"))
        }
    }
    private func footer(frame: AnalysisFrame) -> some View {
        HStack(spacing: m(18)) {
            Text(model.mode == .idle ? model.text("STEREO PCM") : model.localizer.format("%.1f kHz · STEREO", frame.sampleRate / 1000))
            Circle().fill(Palette.line).frame(width: m(3), height: m(3))
            Text("FFT 8192")
            if frame.droppedFrames > 0 { Text(model.localizer.format("%@ dropped frames", String(frame.droppedFrames))).foregroundStyle(Palette.amber) }
            Spacer()
            Toggle(model.text("Peaks"), isOn: $model.showPeaks).toggleStyle(.checkbox)
            Toggle("OLED", isOn: $model.protectOLED).toggleStyle(.checkbox).help(model.text("Pure black, subtle pixel shifting, and dimming during silence. Does not guarantee protection against burn-in."))
            HStack(spacing: m(6)) {
                Image(systemName: "sun.min")
                Slider(value: $model.brightness, in: 0.25...1).frame(width: m(80)).controlSize(.mini)
                    .accessibilityLabel(model.text("Instrument brightness"))
            }.help(model.text("Instrument brightness"))
            Menu("\(model.targetFPS) Hz") {
                Button(model.text("60 Hz · smooth")) { model.targetFPS = 60 }
                Button(model.text("30 Hz · low power")) { model.targetFPS = 30 }
            }.menuStyle(.borderlessButton).fixedSize().help(model.text("Target refresh rate"))
        }.font(.system(size: m(10), design: .monospaced)).foregroundStyle(Palette.secondary)
            .tint(Palette.mint)
    }
    private func writeDiagnostics(frame: AnalysisFrame) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--diagnostics"), args.indices.contains(i+1) else { return }
        let data: [String: Any] = ["mode": String(describing: model.mode), "sampleRate": frame.sampleRate,
            "leftRMS": frame.left.rmsDB, "rightRMS": frame.right.rmsDB,
            "leftPeak": frame.left.peakDB, "correlation": frame.correlation,
            "callbacks": frame.callbacks, "processedFrames": frame.processedFrames,
            "droppedFrames": frame.droppedFrames, "invalidBuffers": frame.invalidBuffers,
            "analysisMS": frame.analysisMS, "status": model.status(frame: frame),
            "uiUpdatesPerSecond": model.displayMetrics.updatesPerSecond]
        // Opt-in development diagnostics only; no audio data or files in normal operation.
        if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
            try? json.write(to: URL(fileURLWithPath: args[i+1]), options: .atomic)
        }
    }
}

struct InstrumentPanel<Content: View>: View {
    @Environment(\.instrumentMetrics) private var metrics
    let title: String
    let detail: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: metrics.size(20)) {
            HStack {
                Text(title).tracking(metrics.size(2)).foregroundStyle(Color(white: 0.76))
                Spacer()
                Text(detail).foregroundStyle(Palette.secondary)
            }.font(.system(size: metrics.size(10), weight: .medium, design: .monospaced))
            content
        }
        .padding(metrics.size(23))
        .overlay(RoundedRectangle(cornerRadius: metrics.size(8)).strokeBorder(Palette.line, lineWidth: metrics.hairline))
    }
}
