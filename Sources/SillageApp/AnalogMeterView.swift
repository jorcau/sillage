import SwiftUI
import AudioAnalysis
import AppLocalization

/// Original instrument artwork drawn at the final display size, including the
/// dial, metal bevels and glass. No bitmap enlargement or external assets.
struct AnalogMeterView: View {
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics
    @Environment(\.appLocalizer) private var localizer

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - metrics.size(30),
                            max(metrics.size(200), geometry.size.height - metrics.size(65)) * 2.75)
            let height = width / 2.75
            VStack(spacing: metrics.size(22)) {
                HStack(spacing: width * 0.023) {
                    AnalogChannelMeter(channel: "L", level: frame.left)
                    AnalogChannelMeter(channel: "R", level: frame.right)
                }
                .padding(width * 0.028)
                .frame(width: width, height: height)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: width * 0.005)
                            .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.055), Color(white: 0.09), .black],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        RoundedRectangle(cornerRadius: width * 0.005)
                            .strokeBorder(LinearGradient(colors: [Color(white: 0.38), Color(white: 0.07), Color(white: 0.22)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: width * 0.002)
                        RoundedRectangle(cornerRadius: width * 0.003)
                            .inset(by: width * 0.009)
                            .stroke(LinearGradient(colors: [.black, Color(white: 0.29), .black],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width * 0.003)
                    }
                }
                .overlay {
                    VStack {
                        HStack { AnalogScrew(); Spacer(); AnalogScrew() }
                        Spacer()
                        HStack { AnalogScrew(); Spacer(); AnalogScrew() }
                    }.padding(width * 0.012).foregroundStyle(.gray)
                        .environment(\.analogScrewSize, width * 0.008)
                }
                .shadow(color: .black.opacity(0.8), radius: width * 0.02, y: width * 0.01)
                Text("0 VU = −18 dBFS · RMS 300 ms")
                    .font(.system(size: metrics.size(10), design: .monospaced))
                    .foregroundStyle(InterfaceColors.secondary)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizer.format("Analog meters, left %.1f, right %.1f VU. Zero VU equals minus 18 dBFS.",
                                            frame.left.rmsDB + 18, frame.right.rmsDB + 18))
    }
}

private struct AnalogScrewSize: EnvironmentKey { static let defaultValue: CGFloat = 8 }
private extension EnvironmentValues {
    var analogScrewSize: CGFloat {
        get { self[AnalogScrewSize.self] }
        set { self[AnalogScrewSize.self] = newValue }
    }
}

private struct AnalogScrew: View {
    @Environment(\.analogScrewSize) private var size
    var body: some View {
        Circle().fill(LinearGradient(colors: [Color(white: 0.43), Color(white: 0.08), Color(white: 0.26)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(.black, lineWidth: 1))
            .overlay(Capsule().fill(.black.opacity(0.9)).frame(width: size * 0.63, height: size * 0.16).rotationEffect(.degrees(-28)))
            .frame(width: size, height: size)
            .shadow(color: .black, radius: size * 0.14, y: size * 0.12)
    }
}

private struct AnalogChannelMeter: View {
    let channel: String
    let level: ChannelLevel

    var body: some View {
        ZStack {
            AnalogDialFace(channel: channel).equatable()
            Canvas(rendersAsynchronously: true) { context, size in
                let dial = AnalogDialGeometry(size: size)
                context.clip(to: Path(dial.face))
                let tip = dial.point(fraction: AnalogMeterScale.needleFraction(rmsDB: level.rmsDB), radius: 1.04)
                var needle = Path()
                needle.move(to: CGPoint(x: dial.pivot.x - size.width * 0.004, y: dial.pivot.y))
                needle.addLine(to: tip)
                needle.addLine(to: CGPoint(x: dial.pivot.x + size.width * 0.004, y: dial.pivot.y))
                needle.closeSubpath()
                var shadow = context
                shadow.translateBy(x: size.width * 0.007, y: size.width * 0.006)
                shadow.addFilter(.blur(radius: size.width * 0.003))
                shadow.fill(needle, with: .color(.black.opacity(0.30)))
                context.fill(needle, with: .color(Color(red: 0.13, green: 0.10, blue: 0.075)))
                let hub = CGRect(x: dial.pivot.x - size.width * 0.022, y: dial.pivot.y - size.width * 0.016,
                                 width: size.width * 0.044, height: size.width * 0.044)
                context.fill(Path(ellipseIn: hub), with: .linearGradient(Gradient(colors: [Color(white: 0.36), .black]),
                                                                        startPoint: hub.origin, endPoint: CGPoint(x: hub.maxX, y: hub.maxY)))
                if level.clipped {
                    let led = CGRect(x: dial.face.maxX - size.width * 0.051, y: dial.face.minY + size.height * 0.035,
                                     width: size.width * 0.018, height: size.width * 0.018)
                    context.fill(Path(ellipseIn: led), with: .color(Color(red: 1, green: 0.16, blue: 0.06)))
                }
            }
            AnalogGlass().allowsHitTesting(false)
        }
        .clipped()
    }
}

private struct AnalogDialGeometry {
    let face: CGRect
    let pivot: CGPoint
    let radius: CGFloat

    init(size: CGSize) {
        face = CGRect(x: size.width * 0.035, y: size.height * 0.055,
                      width: size.width * 0.93, height: size.height * 0.875)
        pivot = CGPoint(x: face.midX, y: face.maxY - face.height * 0.015)
        radius = face.height * 0.71
    }

    func point(fraction: Double, radius multiplier: CGFloat = 1) -> CGPoint {
        let angle = (-52 + 104 * fraction) * .pi / 180
        return CGPoint(x: pivot.x + sin(angle) * radius * multiplier,
                       y: pivot.y - cos(angle) * radius * multiplier)
    }

    func arc(from start: Double, to end: Double, radius: CGFloat = 1) -> Path {
        var path = Path()
        for i in 0...80 {
            let point = point(fraction: start + (end - start) * Double(i) / 80, radius: radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct AnalogDialFace: View, Equatable {
    let channel: String

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let dial = AnalogDialGeometry(size: size)
            let full = CGRect(origin: .zero, size: size)
            let ink = Color(red: 0.14, green: 0.12, blue: 0.085)
            let red = Color(red: 0.63, green: 0.12, blue: 0.065)
            context.fill(Path(full), with: .linearGradient(Gradient(colors: [Color(white: 0.45), Color(white: 0.11), .black, Color(white: 0.24)]),
                                                          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.fill(Path(full.insetBy(dx: size.width * 0.008, dy: size.width * 0.008)), with: .color(Color(white: 0.035)))
            context.fill(Path(dial.face), with: .linearGradient(Gradient(colors: [Color(red: 0.68, green: 0.59, blue: 0.39),
                                                                                 Color(red: 0.92, green: 0.85, blue: 0.64),
                                                                                 Color(red: 0.97, green: 0.88, blue: 0.64)]),
                                                               startPoint: dial.face.origin, endPoint: CGPoint(x: dial.face.minX, y: dial.face.maxY)))
            var paper = context
            paper.clip(to: Path(dial.face))
            for offset in [-0.27, 0.27] {
                let center = CGPoint(x: dial.face.midX + dial.face.width * offset, y: dial.face.maxY + dial.face.height * 0.07)
                paper.fill(Path(dial.face), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.98, blue: 0.73).opacity(0.8), .clear]),
                                                                  center: center, startRadius: 0, endRadius: dial.face.width * 0.65))
            }
            // A small deterministic paper grain, independent of display pixel count.
            for i in 0..<850 {
                let x = dial.face.minX + CGFloat((i * 167 + 19) % 997) / 997 * dial.face.width
                let y = dial.face.minY + CGFloat((i * 317 + 73) % 991) / 991 * dial.face.height
                paper.fill(Path(CGRect(x: x, y: y, width: size.width * 0.0018, height: size.width * 0.0018)),
                           with: .color(ink.opacity(0.06)))
            }
            // Recessed top and side shadows give the paper depth behind the bezel.
            paper.fill(Path(dial.face), with: .linearGradient(Gradient(stops: [
                .init(color: .black.opacity(0.52), location: 0), .init(color: .clear, location: 0.12),
                .init(color: .clear, location: 0.87), .init(color: .black.opacity(0.25), location: 1)]),
                startPoint: dial.face.origin, endPoint: CGPoint(x: dial.face.minX, y: dial.face.maxY)))
            paper.fill(Path(dial.face), with: .linearGradient(Gradient(stops: [
                .init(color: .black.opacity(0.33), location: 0), .init(color: .clear, location: 0.10),
                .init(color: .clear, location: 0.9), .init(color: .black.opacity(0.33), location: 1)]),
                startPoint: dial.face.origin, endPoint: CGPoint(x: dial.face.maxX, y: dial.face.minY)))

            let zero = AnalogMeterScale.fraction(vu: 0)
            context.stroke(dial.arc(from: AnalogMeterScale.fraction(vu: -20), to: zero), with: .color(ink), lineWidth: size.width * 0.003)
            context.stroke(dial.arc(from: zero, to: 1), with: .color(red), lineWidth: size.width * 0.009)
            context.stroke(dial.arc(from: AnalogMeterScale.fraction(vu: -20), to: 1, radius: 0.86), with: .color(ink.opacity(0.7)), lineWidth: size.width * 0.0015)
            let majorMarks = [-20, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3]
            for db in -20...3 {
                let fraction = AnalogMeterScale.fraction(vu: Double(db))
                let major = majorMarks.contains(db)
                var tick = Path()
                tick.move(to: dial.point(fraction: fraction, radius: 0.96))
                tick.addLine(to: dial.point(fraction: fraction, radius: major ? 1.065 : 1.015))
                context.stroke(tick, with: .color(db > 0 ? red : ink), lineWidth: size.width * (major ? 0.0027 : 0.0012))
                if major {
                    let p = dial.point(fraction: fraction, radius: 1.16)
                    let label = db > 0 ? "+\(db)" : "\(db)"
                    context.draw(Text(label).font(.system(size: size.width * 0.032, weight: .medium, design: .rounded))
                        .foregroundColor(db > 0 ? red : ink), at: p)
                }
            }
            for percent in [20, 40, 60, 80, 100] {
                let fraction = Double(percent) / 100 * zero
                let p = dial.point(fraction: fraction, radius: 0.79)
                context.draw(Text("\(percent)").font(.system(size: size.width * 0.018)).foregroundColor(ink.opacity(0.8)), at: p)
            }
            context.draw(Text("VU").font(.system(size: size.width * 0.058, weight: .semibold, design: .serif)).foregroundColor(ink),
                         at: CGPoint(x: dial.face.minX + dial.face.width * 0.11, y: dial.face.minY + dial.face.height * 0.15))
            context.draw(Text(channel).font(.system(size: size.width * 0.033, weight: .medium)).foregroundColor(ink.opacity(0.7)),
                         at: CGPoint(x: dial.face.midX, y: dial.face.maxY - dial.face.height * 0.33))
            context.draw(Text("S I L L A G E").font(.system(size: size.width * 0.024, weight: .medium, design: .rounded)).foregroundColor(ink.opacity(0.85)),
                         at: CGPoint(x: dial.face.midX, y: dial.face.maxY - dial.face.height * 0.20))
            let led = CGRect(x: dial.face.maxX - size.width * 0.055, y: dial.face.minY + size.height * 0.03,
                             width: size.width * 0.026, height: size.width * 0.026)
            context.fill(Path(ellipseIn: led), with: .radialGradient(Gradient(colors: [Color(red: 0.24, green: 0.12, blue: 0.08), .black]),
                                                                       center: CGPoint(x: led.midX - led.width * 0.2, y: led.midY - led.height * 0.2),
                                                                       startRadius: 0, endRadius: led.width * 0.6))
            context.stroke(Path(dial.face), with: .color(.black.opacity(0.8)), lineWidth: size.width * 0.004)
        }
    }
}

private struct AnalogGlass: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let face = AnalogDialGeometry(size: size).face
            context.clip(to: Path(face))
            var reflection = Path()
            reflection.move(to: face.origin)
            reflection.addLine(to: CGPoint(x: face.maxX, y: face.minY))
            reflection.addLine(to: CGPoint(x: face.maxX, y: face.minY + face.height * 0.26))
            reflection.addLine(to: CGPoint(x: face.minX, y: face.minY + face.height * 0.62))
            reflection.closeSubpath()
            context.fill(reflection, with: .linearGradient(Gradient(colors: [.white.opacity(0.14), .white.opacity(0.015)]),
                                                          startPoint: face.origin, endPoint: CGPoint(x: face.midX, y: face.midY)))
            context.stroke(Path(face.insetBy(dx: size.width * 0.005, dy: size.width * 0.005)),
                           with: .color(.white.opacity(0.16)), lineWidth: size.width * 0.002)
        }
    }
}
