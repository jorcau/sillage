import SwiftUI
import AudioAnalysis
import AppLocalization

struct BroadcastMeterView: View {
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics
    @Environment(\.appLocalizer) private var localizer
    var body: some View {
        GeometryReader { geometry in
            let height = max(200, geometry.size.height - metrics.size(20))
            let width = min(geometry.size.width - metrics.size(24), height * 1.50)
            HardwareCabinet(finish: .graphite) {
                HStack(spacing: width * 0.06) {
                    PPMChannel(channel: "L", level: frame.leftPPMDB, clipped: frame.left.clipped)
                    VStack(spacing: height * 0.045) {
                        Text("S I L L A G E").font(.system(size: width * 0.018, weight: .medium))
                        Text("PPM").font(.system(size: width * 0.052, weight: .light, design: .rounded))
                        Rectangle().fill(Color(white: 0.27)).frame(height: 1)
                        Text("TEST\n−18 dBFS").multilineTextAlignment(.center)
                        Text("10 ms\n24 dB / 2.8 s").multilineTextAlignment(.center)
                        StereoPilotLights(frame: frame).frame(height: height * 0.15)
                    }.font(.system(size: width * 0.014, design: .monospaced)).foregroundStyle(Color(white: 0.68))
                        .frame(width: width * 0.23)
                    PPMChannel(channel: "R", level: frame.rightPPMDB, clipped: frame.right.clipped)
                }
            }.frame(width: width, height: height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizer.format("Quasi-peak levels, left %.1f, right %.1f dBFS", frame.leftPPMDB, frame.rightPPMDB))
    }
}

private struct PPMChannel: View {
    let channel: String
    let level: Float
    let clipped: Bool
    var body: some View {
        ZStack {
            PPMFace(channel: channel).equatable()
            Canvas { context, size in
                let face = CGRect(x: size.width * 0.07, y: size.height * 0.03, width: size.width * 0.86, height: size.height * 0.90)
                context.clip(to: Path(face))
                let proportion = CGFloat(max(0, min(1, (level + 30) / 24)))
                let y = size.height * (0.80 - 0.64 * proportion)
                var pointer = Path()
                pointer.move(to: CGPoint(x: size.width * 0.52, y: y + size.height * 0.005))
                pointer.addLine(to: CGPoint(x: size.width * 0.83, y: y))
                var shade = context; shade.translateBy(x: 2, y: 3); shade.addFilter(.blur(radius: 2))
                shade.stroke(pointer, with: .color(.black), lineWidth: 5)
                var halo = context; halo.addFilter(.blur(radius: size.width * 0.013))
                halo.stroke(pointer, with: .color(.white.opacity(0.2)), lineWidth: size.width * 0.014)
                context.stroke(pointer, with: .color(Color(white: 0.95)), lineWidth: max(1.5, size.width * 0.010))
                HardwareDrawing.lamp(context, center: CGPoint(x: size.width * 0.78, y: size.height * 0.085),
                    radius: size.width * 0.025, color: .red, lit: clipped)
                context.draw(Text(String(format: "%.1f", level)).font(.system(size: size.width * 0.065, design: .monospaced)).foregroundColor(Color(white: 0.7)),
                    at: CGPoint(x: size.width / 2, y: size.height * 0.885))
            }
        }
    }
}

private struct PPMFace: View, Equatable {
    let channel: String
    var body: some View {
        Canvas(opaque: true) { context, size in
            let all = CGRect(origin: .zero, size: size)
            context.fill(Path(all), with: .linearGradient(Gradient(colors: [Color(white: 0.31), .black, Color(white: 0.18)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            let face = all.insetBy(dx: size.width * 0.05, dy: size.height * 0.02)
            context.fill(Path(face), with: .linearGradient(Gradient(colors: [Color(white: 0.018), Color(white: 0.065), Color(white: 0.02)]),
                startPoint: face.origin, endPoint: CGPoint(x: face.maxX, y: face.maxY)))
            for db in stride(from: -12, through: 12, by: 2) {
                let y = size.height * (0.80 - 0.64 * CGFloat(db + 12) / 24)
                let major = db % 4 == 0
                var tick = Path(); tick.move(to: CGPoint(x: size.width * (major ? 0.61 : 0.69), y: y))
                tick.addLine(to: CGPoint(x: size.width * 0.86, y: y))
                context.stroke(tick, with: .color(db >= 10 ? Color(red: 1, green: 0.48, blue: 0.2) : .white.opacity(0.80)), lineWidth: major ? 1.7 : 1)
                if major {
                    let text = db == 0 ? "TEST" : db > 0 ? "+\(db)" : "\(db)"
                    context.draw(Text(text).font(.system(size: size.width * (db == 0 ? 0.075 : 0.085), weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.87)),
                        at: CGPoint(x: size.width * 0.35, y: y))
                }
            }
            context.draw(Text(channel).font(.system(size: size.width * 0.12, weight: .medium)).foregroundColor(.white.opacity(0.8)),
                at: CGPoint(x: size.width * 0.34, y: size.height * 0.084))
            context.draw(Text("dBFS").font(.system(size: size.width * 0.049, design: .monospaced)).foregroundColor(.gray),
                at: CGPoint(x: size.width / 2, y: size.height * 0.939))
            let reflection = CGRect(x: face.minX, y: face.minY, width: face.width * 0.26, height: face.height)
            context.fill(Path(reflection), with: .linearGradient(Gradient(colors: [.white.opacity(0.07), .clear]), startPoint: reflection.origin,
                endPoint: CGPoint(x: reflection.maxX, y: reflection.minY)))
        }
    }
}

struct CorrelationDial: View {
    let value: Float
    @Environment(\.appLocalizer) private var localizer
    var body: some View {
        Canvas { context, size in
            let width = min(size.width, size.height * 1.7)
            let rect = CGRect(x: (size.width - width) / 2, y: (size.height - width / 1.7) / 2, width: width, height: width / 1.7)
            context.fill(Path(roundedRect: rect, cornerRadius: width * 0.025), with: .linearGradient(Gradient(colors: [Color(white: 0.40), .black]),
                startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            let face = rect.insetBy(dx: width * 0.025, dy: width * 0.025)
            context.fill(Path(face), with: .linearGradient(Gradient(colors: [Color(red: 0.70, green: 0.66, blue: 0.49), Color(red: 0.94, green: 0.88, blue: 0.66)]),
                startPoint: face.origin, endPoint: CGPoint(x: face.minX, y: face.maxY)))
            context.fill(Path(face), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.92, blue: 0.65).opacity(0.7), .clear]),
                center: CGPoint(x: face.midX, y: face.maxY), startRadius: 0, endRadius: face.width * 0.65))
            var recess = context
            recess.clip(to: Path(face))
            recess.addFilter(.blur(radius: width * 0.018))
            recess.stroke(Path(face), with: .color(.black.opacity(0.65)), lineWidth: width * 0.025)
            let pivot = CGPoint(x: face.midX, y: face.maxY - face.height * 0.04)
            func point(_ v: Double, _ radius: Double) -> CGPoint {
                let angle = v * 52 * .pi / 180
                return CGPoint(x: pivot.x + sin(angle) * face.height * radius, y: pivot.y - cos(angle) * face.height * radius)
            }
            for i in -5...5 {
                let v = Double(i) / 5
                var tick = Path(); tick.move(to: point(v, 0.66)); tick.addLine(to: point(v, 0.75))
                context.stroke(tick, with: .color(i < 0 ? .red.opacity(0.65) : .black.opacity(0.8)), lineWidth: 1)
                if i % 5 == 0 {
                    context.draw(Text(i < 0 ? "−1" : i == 0 ? "0" : "+1").font(.system(size: width * 0.06, design: .rounded)).foregroundColor(.black.opacity(0.8)), at: point(v, 0.90))
                }
            }
            var needle = Path(); needle.move(to: pivot); needle.addLine(to: point(Double(max(-1, min(1, value))), 0.77))
            var shadow = context
            shadow.translateBy(x: width * 0.010, y: width * 0.008)
            shadow.addFilter(.blur(radius: width * 0.006))
            shadow.stroke(needle, with: .color(.black.opacity(0.5)), lineWidth: width * 0.012)
            context.stroke(needle, with: .color(Color(red: 0.40, green: 0.06, blue: 0.025)), lineWidth: max(1.2, width * 0.007))
            let hub = CGRect(x: pivot.x - width * 0.035, y: pivot.y - width * 0.022, width: width * 0.07, height: width * 0.04)
            context.fill(Path(ellipseIn: hub), with: .linearGradient(Gradient(colors: [Color(white: 0.35), .black]),
                startPoint: hub.origin, endPoint: CGPoint(x: hub.midX, y: hub.maxY)))
            context.draw(Text("CORR").font(.system(size: width * 0.055, weight: .medium, design: .monospaced)).foregroundColor(.black.opacity(0.68)),
                at: CGPoint(x: face.midX, y: face.maxY - face.height * 0.25))
            var glass = context
            glass.clip(to: Path(face))
            let reflection = CGRect(x: face.minX - width * 0.1, y: face.minY - face.height * 0.4, width: face.width * 1.2, height: face.height * 0.9)
            glass.fill(Path(ellipseIn: reflection), with: .linearGradient(Gradient(colors: [.white.opacity(0.3), .clear]),
                startPoint: face.origin, endPoint: CGPoint(x: face.midX, y: face.midY)))
            context.stroke(Path(face), with: .linearGradient(Gradient(colors: [.black.opacity(0.8), .white.opacity(0.25)]),
                startPoint: face.origin, endPoint: CGPoint(x: face.maxX, y: face.maxY)), lineWidth: max(1, width * 0.008))
        }
        .accessibilityLabel(localizer.format("Stereo goniometer, correlation %.2f", value))
    }
}

struct StereoPilotLights: View {
    let frame: AnalysisFrame
    var labelColor: Color = Color(white: 0.65)
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width * 0.035, size.height * 0.07)
            for (i, clipped) in [frame.left.clipped, frame.right.clipped].enumerated() {
                let x = size.width * (i == 0 ? 0.28 : 0.72)
                HardwareDrawing.lamp(context, center: CGPoint(x: x, y: size.height * 0.38), radius: radius, color: .red, lit: clipped)
                context.draw(Text(i == 0 ? "L · CLIP" : "R · CLIP").font(.system(size: max(7, size.width * 0.05), design: .monospaced)).foregroundColor(labelColor),
                    at: CGPoint(x: x, y: size.height * 0.74))
            }
        }
    }
}
