import SwiftUI
import AudioAnalysis
import AppLocalization

// Canvas is allocated at its final view size. All text and geometry are drawn in
// those coordinates, with no CGContext/view scaling or enlarged backing texture.
private struct InstrumentDrawing {
    let context: GraphicsContext
    let metrics: InstrumentMetrics
    func m(_ points: CGFloat) -> CGFloat { metrics.size(points) }
    func snap(_ points: CGFloat) -> CGFloat { metrics.snap(points) }

    func label(_ text: String, x: CGFloat, y: CGFloat, color: Color = Palette.secondary,
               size: CGFloat = 10, anchor: UnitPoint = .center) {
        context.draw(Text(text).font(.system(size: m(size), design: .monospaced)).foregroundColor(color),
                     at: CGPoint(x: snap(x), y: snap(y)), anchor: anchor)
    }
    func line(_ a: CGPoint, _ b: CGPoint, color: Color, width: CGFloat? = nil) {
        line(a, b, shading: .color(color), width: width)
    }
    func line(_ a: CGPoint, _ b: CGPoint, shading: GraphicsContext.Shading, width: CGFloat? = nil) {
        let strokeWidth = max(metrics.hairline, snap(width ?? metrics.hairline))
        var from = a, to = b
        if a.y == b.y {
            from.y = metrics.strokeCenter(a.y, width: strokeWidth); to.y = from.y
        } else if a.x == b.x {
            from.x = metrics.strokeCenter(a.x, width: strokeWidth); to.x = from.x
        }
        var path = Path(); path.move(to: from); path.addLine(to: to)
        context.stroke(path, with: shading, lineWidth: strokeWidth)
    }
}

struct SpectrumView: View {
    @Environment(\.instrumentPalette) private var palette
    @Environment(\.appLocalizer) private var localizer
    let frame: AnalysisFrame
    let showPeaks: Bool
    @Environment(\.instrumentMetrics) private var metrics
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let d = InstrumentDrawing(context: context, metrics: metrics)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let plot = CGRect(x: d.m(32), y: d.m(10),
                              width: max(1, d.snap(size.width - d.m(44))),
                              height: max(1, d.snap(size.height - d.m(43))))
            func y(_ db: Float) -> CGFloat {
                plot.maxY - CGFloat(max(0, min(1, (db + 90) / 90))) * plot.height
            }
            func x(_ hz: Double) -> CGFloat { plot.minX + CGFloat(log10(hz / 20) / 3) * plot.width }
            for db in stride(from: 0, through: -90, by: -15) {
                let py = y(Float(db))
                d.line(CGPoint(x: plot.minX, y: py), CGPoint(x: plot.maxX, y: py),
                       color: Color(white: db == -90 ? 0.18 : 0.075))
                d.label("\(db)", x: plot.minX - d.m(10), y: py, size: 9, anchor: .trailing)
            }
            for (hz, text) in [(20.0,"20"),(50,"50"),(100,"100"),(200,"200"),(500,"500"),
                               (1000,"1k"),(2000,"2k"),(5000,"5k"),(10000,"10k"),(20000,"20k")] {
                let px = x(hz)
                d.line(CGPoint(x: px, y: plot.minY), CGPoint(x: px, y: plot.maxY), color: Color(white: 0.055))
                d.label(text, x: px, y: plot.maxY + d.m(19), size: 9)
            }
            let width = plot.width / CGFloat(frame.spectrum.count)
            // Map the palette across the logarithmic frequency axis, shared by every bar.
            let left = CGPoint(x: plot.minX, y: plot.minY)
            let rightEdge = CGPoint(x: plot.maxX, y: plot.minY)
            let fill: GraphicsContext.Shading = palette == .mint
                ? .linearGradient(Gradient(colors: [palette.accent.opacity(0.13), palette.accent.opacity(0.7)]),
                    startPoint: CGPoint(x: 0, y: plot.maxY), endPoint: CGPoint(x: 0, y: plot.minY))
                : palette.shading(from: left, to: rightEdge, opacity: 0.72)
            let peak = palette.shading(from: left, to: rightEdge, opacity: 0.90)
            for i in frame.spectrum.indices {
                let px = d.snap(plot.minX + CGFloat(i) * width)
                let right = d.snap(plot.minX + (CGFloat(i) + 0.72) * width)
                let top = d.snap(y(frame.spectrum[i]))
                let rect = CGRect(x: px, y: top, width: max(metrics.hairline, right - px),
                                  height: max(0, plot.maxY - top))
                context.fill(Path(rect), with: fill)
                if showPeaks && frame.spectrumHold[i] > -89 {
                    d.line(CGPoint(x: px, y: y(frame.spectrumHold[i])),
                           CGPoint(x: right, y: y(frame.spectrumHold[i])), shading: peak)
                }
            }
        }
        .accessibilityLabel(localizer.text("Stereo spectrum, 20 hertz to 20 kilohertz, logarithmic scale"))
    }
}

struct PhaseView: View {
    @Environment(\.instrumentPalette) private var palette
    @Environment(\.appLocalizer) private var localizer
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let d = InstrumentDrawing(context: context, metrics: metrics)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let radius = max(d.m(10), min(size.width * 0.43, (size.height - d.m(78)) * 0.46))
            let center = CGPoint(x: d.snap(size.width/2), y: d.snap((size.height - d.m(60))/2))
            let circle = CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2)
            context.stroke(Path(ellipseIn: circle), with: .color(Color(white: 0.10)), lineWidth: metrics.hairline)
            context.stroke(Path(ellipseIn: circle.insetBy(dx: radius*0.5, dy: radius*0.5)),
                           with: .color(Color(white: 0.06)), lineWidth: metrics.hairline)
            d.line(CGPoint(x: center.x-radius, y: center.y), CGPoint(x: center.x+radius, y: center.y), color: Palette.line)
            d.line(CGPoint(x: center.x, y: center.y-radius), CGPoint(x: center.x, y: center.y+radius), color: Palette.line)
            for sign in [-1.0, 1.0] {
                d.line(CGPoint(x: center.x-radius*0.707, y: center.y-sign*radius*0.707),
                       CGPoint(x: center.x+radius*0.707, y: center.y+sign*radius*0.707), color: Color(white: 0.07))
            }
            d.label("M", x: center.x, y: center.y-radius-d.m(10), size: 9)
            d.label("L", x: center.x-radius*0.80, y: center.y-radius*0.80, size: 9)
            d.label("R", x: center.x+radius*0.80, y: center.y-radius*0.80, size: 9)
            var trail = Path()
            for (i, point) in frame.phase.enumerated() {
                let p = CGPoint(x: center.x + CGFloat(max(-1,min(1,point.x))) * radius,
                                y: center.y - CGFloat(max(-1,min(1,point.y))) * radius)
                if i == 0 { trail.move(to: p) } else { trail.addLine(to: p) }
            }
            // Keep antialiasing on the signal itself: continuous audio geometry is not a pixel grid.
            // Color the trace spatially without changing its fixed-gain geometry.
            // Its own bounds keep color variation visible at quiet listening levels.
            let bounds = trail.boundingRect
            let traceShading: GraphicsContext.Shading = bounds.isEmpty && bounds.width == 0 && bounds.height == 0
                ? .color(palette.accent.opacity(0.50))
                : palette.shading(from: CGPoint(x: bounds.minX, y: bounds.maxY),
                                  to: CGPoint(x: bounds.maxX, y: bounds.minY), opacity: 0.50)
            context.stroke(trail, with: traceShading,
                           style: StrokeStyle(lineWidth: d.m(0.85), lineJoin: .round))
            let barY = size.height - d.m(28)
            d.line(CGPoint(x: d.m(8), y: barY), CGPoint(x: size.width-d.m(8), y: barY),
                   color: Palette.line, width: d.m(2))
            let marker = d.m(8) + CGFloat((frame.correlation+1)/2) * (size.width-d.m(16))
            context.fill(Path(ellipseIn: CGRect(x: marker-d.m(3), y: barY-d.m(3), width: d.m(6), height: d.m(6))),
                         with: .color(frame.correlation < 0 ? Palette.amber : palette.accent))
            d.label("−1", x: d.m(8), y: size.height-d.m(7), size: 9)
            d.label(String(format: "CORR  %+.2f", frame.correlation), x: size.width/2,
                    y: size.height-d.m(7), color: Color(white: 0.65), size: 9)
            d.label("+1", x: size.width-d.m(8), y: size.height-d.m(7), size: 9)
        }
        .accessibilityLabel(localizer.format("Stereo goniometer, correlation %.2f", frame.correlation))
    }
}

struct LevelView: View {
    @Environment(\.instrumentPalette) private var palette
    @Environment(\.appLocalizer) private var localizer
    let frame: AnalysisFrame
    let showPeaks: Bool
    @Environment(\.instrumentMetrics) private var metrics
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let d = InstrumentDrawing(context: context, metrics: metrics)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let start = d.m(28), end = max(d.m(100), d.snap(size.width-d.m(154)))
            func x(_ db: Float) -> CGFloat {
                d.snap(start + CGFloat(max(0,min(1,(db+60)/60))) * (end-start))
            }
            // Anchor colors to the full dBFS scale, not to the moving bar length.
            let gradientStart = CGPoint(x: start, y: 0)
            let gradientEnd = CGPoint(x: end, y: 0)
            let peakFill = palette.shading(from: gradientStart, to: gradientEnd, opacity: 0.20)
            let rmsFill = palette.shading(from: gradientStart, to: gradientEnd, opacity: 0.85)
            let holdFill = palette.shading(from: gradientStart, to: gradientEnd)
            for (i, level) in [frame.left, frame.right].enumerated() {
                let y = d.m(CGFloat(i)*42 + 29)
                d.label(i == 0 ? "L" : "R", x: 0, y: y+d.m(5), color: Color(white: 0.82), size: 12, anchor: .leading)
                let track = CGRect(x: start, y: y, width: end-start, height: d.m(9))
                context.fill(Path(roundedRect: track, cornerRadius: d.m(2)), with: .color(Color(white: 0.085)))
                context.fill(Path(CGRect(x: start, y: y, width: x(level.peakDB)-start, height: d.m(9))),
                             with: peakFill)
                context.fill(Path(CGRect(x: start, y: y, width: x(level.rmsDB)-start, height: d.m(9))),
                             with: rmsFill)
                if showPeaks {
                    d.line(CGPoint(x: x(level.holdDB), y: y-d.m(2)),
                           CGPoint(x: x(level.holdDB), y: y+d.m(11)),
                           shading: level.holdDB > -1 ? .color(Palette.amber) : holdFill, width: d.m(1.5))
                }
                if level.clipped {
                    context.fill(Path(ellipseIn: CGRect(x: end+d.m(9), y: y+d.m(2), width: d.m(5), height: d.m(5))), with: .color(.red))
                }
                d.label(level.rmsDB <= -89 ? "−∞" : String(format: "%5.1f", level.rmsDB),
                        x: size.width-d.m(70), y: y+d.m(5), color: Color(white: 0.78), size: 14, anchor: .trailing)
                d.label(level.peakDB <= -89 ? "−∞" : String(format: "%5.1f", level.peakDB),
                        x: size.width, y: y+d.m(5), color: palette.peak, size: 14, anchor: .trailing)
            }
            for db in [-60,-48,-36,-24,-18,-12,-6,0] {
                d.label("\(db)", x: x(Float(db)), y: d.m(6), size: 9)
                d.line(CGPoint(x: x(Float(db)), y: d.m(17)), CGPoint(x: x(Float(db)), y: d.m(20)), color: Palette.line)
            }
            d.label("RMS", x: size.width-d.m(70), y: d.m(6), size: 9, anchor: .trailing)
            d.label(localizer.text("PEAK"), x: size.width, y: d.m(6), size: 9, anchor: .trailing)
            d.label(localizer.text("INTEGRATION") + " 300 ms", x: start, y: d.m(110), size: 9, anchor: .leading)
            d.label(localizer.text("HOLD 1.5 s"), x: end, y: d.m(110), size: 9, anchor: .trailing)
        }
        .accessibilityLabel(localizer.format("RMS levels, left %.1f, right %.1f dBFS", frame.left.rmsDB, frame.right.rmsDB))
    }
}
