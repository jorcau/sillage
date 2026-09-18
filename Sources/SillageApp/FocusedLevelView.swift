import SwiftUI
import AudioAnalysis
import AppLocalization

/// Large digital stereo meters using the existing RMS, sample-peak and hold values.
struct FocusedLevelView: View {
    @Environment(\.instrumentTheme) private var theme
    @Environment(\.instrumentMetrics) private var metrics
    @Environment(\.appLocalizer) private var localizer
    let frame: AnalysisFrame
    let showPeaks: Bool

    var body: some View {
        let strings = localizer
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let d = InstrumentDrawing(context: context, metrics: metrics)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let contentWidth = min(size.width, d.m(860))
            let spacing = contentWidth * 0.5
            let meterWidth = d.snap(min(d.m(160), contentWidth * 0.20))
            let top = d.m(38), bottom = max(top + d.m(30), d.snap(size.height - d.m(94)))
            func y(_ db: Float) -> CGFloat {
                d.snap(bottom - CGFloat(max(0, min(1, (db + 60) / 60))) * (bottom - top))
            }
            func number(_ db: Float) -> String {
                db <= -89 ? "−∞" : strings.format("%.1f", db)
            }
            let start = CGPoint(x: 0, y: bottom), end = CGPoint(x: 0, y: top)
            let rmsFill = theme.shading(from: start, to: end, opacity: 0.85)
            let peakFill = theme.shading(from: start, to: end, opacity: 0.22)
            let holdFill = theme.shading(from: start, to: end)

            // Both channels share the fixed -60...0 dBFS scale, even at silence.
            for (index, level) in [frame.left, frame.right].enumerated() {
                let center = d.snap(size.width / 2 + (CGFloat(index) - 0.5) * spacing)
                let left = d.snap(center - meterWidth / 2)
                let right = left + meterWidth
                d.label(index == 0 ? "L" : "R", x: center, y: d.m(11),
                        color: Color(white: 0.82), size: 16)
                let track = CGRect(x: left, y: top, width: meterWidth, height: bottom - top)
                context.fill(Path(track), with: .color(Color(white: 0.045)))
                for db in [-60, -48, -36, -24, -18, -12, -6, -3, 0] {
                    d.line(CGPoint(x: left - d.m(8), y: y(Float(db))),
                           CGPoint(x: right + d.m(8), y: y(Float(db))), color: InterfaceColors.line)
                    let labelX = index == 0 ? left - d.m(16) : right + d.m(16)
                    d.label("\(db)", x: labelX, y: y(Float(db)), size: 10,
                            anchor: index == 0 ? .trailing : .leading)
                }
                context.fill(Path(CGRect(x: left, y: y(level.peakDB), width: meterWidth,
                                         height: bottom - y(level.peakDB))), with: peakFill)
                let inset = d.m(5)
                context.fill(Path(CGRect(x: left + inset, y: y(level.rmsDB), width: meterWidth - 2 * inset,
                                         height: bottom - y(level.rmsDB))), with: rmsFill)
                if showPeaks {
                    d.line(CGPoint(x: left - d.m(3), y: y(level.holdDB)),
                           CGPoint(x: right + d.m(3), y: y(level.holdDB)),
                           shading: level.holdDB > -1 ? .color(InterfaceColors.amber) : holdFill,
                           width: d.m(1.5))
                }
                if level.clipped {
                    d.label("CLIP", x: right, y: d.m(11), color: .red, size: 10, anchor: .trailing)
                }
                let readoutOffset = d.m(60)
                d.label("RMS", x: center - readoutOffset, y: bottom + d.m(24), size: 9)
                d.label(localizer.text("PEAK"), x: center + readoutOffset, y: bottom + d.m(24), size: 9)
                d.label(number(level.rmsDB), x: center - readoutOffset, y: bottom + d.m(47),
                        color: Color(white: 0.82), size: 24)
                d.label(number(level.peakDB), x: center + readoutOffset, y: bottom + d.m(47),
                        color: theme.peak, size: 24)
            }
            d.label(localizer.text("INTEGRATION") + " 300 ms  ·  " + localizer.text("HOLD 1.5 s"),
                    x: size.width / 2, y: size.height - d.m(8), size: 9)
        }
        .accessibilityLabel(localizer.format("RMS levels, left %.1f, right %.1f dBFS", frame.left.rmsDB, frame.right.rmsDB))
    }
}
