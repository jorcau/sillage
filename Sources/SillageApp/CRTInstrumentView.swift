import SwiftUI
import AudioAnalysis
import AppLocalization

enum CRTInstrumentKind { case waveform, phase }

struct CRTInstrumentView: View {
    let frame: AnalysisFrame
    let kind: CRTInstrumentKind
    @Environment(\.instrumentMetrics) private var metrics

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - metrics.size(24), geometry.size.height * 1.85)
            HardwareCabinet(finish: .graphite) {
                VStack(spacing: width * 0.012) {
                    HStack {
                        Text(kind == .waveform ? "SILLAGE  /  DUAL TRACE" : "SILLAGE  /  STEREO VECTORSCOPE")
                        Spacer()
                        Text(kind == .waveform ? String(format: "%.1f ms · ±1 FS", frame.waveformDuration * 1_000) : "X = (L−R)/2 · Y = (L+R)/2")
                    }.font(.system(size: width * 0.010, weight: .medium, design: .monospaced)).foregroundStyle(Color(white: 0.65))
                    if kind == .phase {
                        HStack(spacing: width * 0.032) {
                            CRTScreen(frame: frame, kind: .phase).frame(maxWidth: .infinity)
                            VStack(spacing: width * 0.04) {
                                CorrelationDial(value: frame.correlation)
                                StereoPilotLights(frame: frame)
                            }.frame(width: width * 0.24)
                        }
                    } else {
                        CRTScreen(frame: frame, kind: .waveform)
                    }
                }
            }.frame(width: width, height: width / 1.85)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

@MainActor
private final class PhosphorPersistence: ObservableObject {
    struct Trace { let phase: [StereoPoint]; let waveform: [WaveformColumn]; let time: TimeInterval }
    @Published var traces: [Trace] = []
    private var lastCapture: TimeInterval = 0

    func capture(_ frame: AnalysisFrame) {
        if frame.processedFrames == 0 { traces = []; lastCapture = 0; return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCapture >= 0.045 else { return }
        lastCapture = now
        traces.removeAll { now - $0.time > 0.20 }
        traces.append(Trace(phase: frame.phase, waveform: frame.waveform, time: now))
        if traces.count > 4 { traces.removeFirst(traces.count - 4) }
    }
}

struct CRTScreen: View {
    let frame: AnalysisFrame
    let kind: CRTInstrumentKind
    @StateObject private var persistence = PhosphorPersistence()
    @Environment(\.appLocalizer) private var localizer
    private var phosphor: Color { kind == .waveform ? Color(red: 0.31, green: 1, blue: 0.55) : Color(red: 1, green: 0.65, blue: 0.23) }

    var body: some View {
        ZStack {
            CRTGlassFace(kind: kind).equatable()
            Canvas(rendersAsynchronously: true) { context, size in
                let screen = CRTGeometry(size: size, kind: kind)
                context.clip(to: screen.mask)
                let now = ProcessInfo.processInfo.systemUptime
                for trace in persistence.traces {
                    let age = now - trace.time
                    if age > 0 && age < 0.22 {
                        drawSignal(context, screen: screen, phase: trace.phase, waveform: trace.waveform,
                                   opacity: 0.15 * (1 - age / 0.22), glow: false)
                    }
                }
                drawSignal(context, screen: screen, phase: frame.phase, waveform: frame.waveform, opacity: 0.94, glow: true)
            }
            CRTGlassReflection(kind: kind)
        }
        .onAppear { persistence.capture(frame) }
        .onChange(of: frame.processedFrames) { _, _ in persistence.capture(frame) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind == .waveform ? localizer.format("Stereo waveform, %.1f millisecond sweep, fixed full-scale amplitude", frame.waveformDuration * 1_000)
                            : localizer.format("Stereo goniometer, correlation %.2f", frame.correlation))
    }

    private func drawSignal(_ context: GraphicsContext, screen: CRTGeometry, phase: [StereoPoint], waveform: [WaveformColumn], opacity: Double, glow: Bool) {
        let plot = screen.plot
        var path = Path()
        if kind == .phase {
            for (i, point) in phase.enumerated() {
                let p = CGPoint(x: plot.midX + CGFloat(max(-1, min(1, point.x))) * plot.width * 0.44,
                                y: plot.midY - CGFloat(max(-1, min(1, point.y))) * plot.height * 0.44)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
        } else {
            for channel in 0..<2 {
                let center = plot.minY + plot.height * (channel == 0 ? 0.27 : 0.73)
                let amplitude = plot.height * 0.205
                for (i, column) in waveform.enumerated() {
                    let low = channel == 0 ? column.leftMin : column.rightMin
                    let high = channel == 0 ? column.leftMax : column.rightMax
                    let x = plot.minX + CGFloat(i) / CGFloat(max(1, waveform.count - 1)) * plot.width
                    let y = center - CGFloat(max(-1, min(1, (low + high) * 0.5))) * amplitude
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    if high - low > 0.005 {
                        path.move(to: CGPoint(x: x, y: center - CGFloat(max(-1, min(1, high))) * amplitude))
                        path.addLine(to: CGPoint(x: x, y: center - CGFloat(max(-1, min(1, low))) * amplitude))
                        path.move(to: CGPoint(x: x, y: y))
                    }
                }
            }
        }
        let width = max(0.8, plot.height * 0.0024)
        if glow {
            var halo = context
            halo.addFilter(.blur(radius: width * 3.5))
            halo.stroke(path, with: .color(phosphor.opacity(opacity * 0.42)), lineWidth: width * 3)
        }
        context.stroke(path, with: .color(phosphor.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineJoin: .round))
        if glow { context.stroke(path, with: .color(.white.opacity(opacity * 0.55)), lineWidth: width * 0.30) }
    }
}

private struct CRTGeometry {
    let plot: CGRect
    let mask: Path
    init(size: CGSize, kind: CRTInstrumentKind) {
        let inset = min(size.width, size.height) * 0.075
        if kind == .phase {
            let diameter = min(size.width, size.height) - inset * 2
            plot = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            mask = Path(ellipseIn: plot)
        } else {
            plot = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            mask = Path(roundedRect: plot, cornerRadius: plot.height * 0.10)
        }
    }
}

private struct CRTGlassFace: View, Equatable {
    let kind: CRTInstrumentKind
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let tube = CRTGeometry(size: size, kind: kind)
            let plot = tube.plot
            let amber = kind == .phase
            let color = amber ? Color(red: 0.57, green: 0.35, blue: 0.11) : Color(red: 0.12, green: 0.45, blue: 0.25)
            context.stroke(tube.mask, with: .linearGradient(Gradient(colors: [Color(white: 0.045), Color(white: 0.24), .black]),
                startPoint: plot.origin, endPoint: CGPoint(x: plot.maxX, y: plot.maxY)), lineWidth: min(size.width, size.height) * 0.075)
            context.fill(tube.mask, with: .radialGradient(Gradient(colors: [color.opacity(0.16), Color(white: 0.015), .black]),
                center: CGPoint(x: plot.midX, y: plot.midY), startRadius: 0, endRadius: plot.width * 0.72))
            var glass = context; glass.clip(to: tube.mask)
            for i in 0...10 {
                let x = plot.minX + plot.width * CGFloat(i) / 10
                let y = plot.minY + plot.height * CGFloat(i) / 10
                var grid = Path()
                grid.move(to: CGPoint(x: x, y: plot.minY)); grid.addLine(to: CGPoint(x: x, y: plot.maxY))
                grid.move(to: CGPoint(x: plot.minX, y: y)); grid.addLine(to: CGPoint(x: plot.maxX, y: y))
                glass.stroke(grid, with: .color(color.opacity(i == 5 ? 0.47 : 0.20)), lineWidth: 0.8)
            }
            if amber {
                for ratio in [0.5, 0.9] {
                    glass.stroke(Path(ellipseIn: plot.insetBy(dx: plot.width * (1 - ratio) / 2, dy: plot.height * (1 - ratio) / 2)),
                        with: .color(color.opacity(0.26)), lineWidth: 0.8)
                }
                for (text, x, y) in [("M", 0.5, 0.06), ("L", 0.18, 0.18), ("R", 0.82, 0.18), ("S", 0.94, 0.5)] {
                    glass.draw(Text(text).font(.system(size: plot.height * 0.034, design: .monospaced)).foregroundColor(color.opacity(0.7)),
                        at: CGPoint(x: plot.minX + plot.width * x, y: plot.minY + plot.height * y))
                }
            } else {
                for (text, y) in [("L", 0.27), ("R", 0.73)] {
                    glass.draw(Text(text).font(.system(size: plot.height * 0.035, design: .monospaced)).foregroundColor(color),
                        at: CGPoint(x: plot.minX + plot.width * 0.025, y: plot.minY + plot.height * y))
                }
            }
            // Fixed-density scan texture, independent of a 4K backing texture.
            for i in 0..<160 {
                let y = plot.minY + CGFloat(i) / 160 * plot.height
                var scan = Path(); scan.move(to: CGPoint(x: plot.minX, y: y)); scan.addLine(to: CGPoint(x: plot.maxX, y: y))
                glass.stroke(scan, with: .color(.black.opacity(0.16)), lineWidth: 0.6)
            }
        }
    }
}

private struct CRTGlassReflection: View {
    let kind: CRTInstrumentKind
    var body: some View {
        Canvas { context, size in
            let tube = CRTGeometry(size: size, kind: kind), plot = tube.plot
            context.clip(to: tube.mask)
            let reflection = CGRect(x: plot.minX - plot.width * 0.2, y: plot.minY - plot.height * 0.45,
                                    width: plot.width * 1.15, height: plot.height * 0.80)
            context.fill(Path(ellipseIn: reflection), with: .linearGradient(Gradient(colors: [.white.opacity(0.085), .clear]),
                startPoint: CGPoint(x: plot.minX, y: plot.minY), endPoint: CGPoint(x: plot.midX, y: plot.midY)))
            context.stroke(tube.mask, with: .linearGradient(Gradient(colors: [.white.opacity(0.20), .clear, .black.opacity(0.8)]),
                startPoint: plot.origin, endPoint: CGPoint(x: plot.maxX, y: plot.maxY)), lineWidth: plot.height * 0.01)
        }.allowsHitTesting(false)
    }
}
