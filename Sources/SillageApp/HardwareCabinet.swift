import SwiftUI

enum CabinetFinish { case graphite, silver, walnut }

/// Static material layers remain separate from instrument animation.
struct HardwareCabinet<Content: View>: View {
    var finish: CabinetFinish = .graphite
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CabinetSurface(finish: finish).equatable()
                content
                    .padding(.horizontal, geometry.size.width * (finish == .walnut ? 0.077 : 0.035))
                    .padding(.vertical, geometry.size.height * 0.075)
            }
        }
    }
}

private struct CabinetSurface: View, Equatable {
    let finish: CabinetFinish
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let all = CGRect(origin: .zero, size: size)
            context.fill(Path(all), with: .color(.black))
            let cabinet = all.insetBy(dx: 2, dy: 2)
            let bright = finish != .graphite
            let panel = finish == .walnut ? cabinet.insetBy(dx: size.width * 0.055, dy: 0) : cabinet
            if finish == .walnut {
                context.fill(Path(roundedRect: cabinet, cornerRadius: 8), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.15, green: 0.064, blue: 0.030), Color(red: 0.39, green: 0.20, blue: 0.09), Color(red: 0.12, green: 0.047, blue: 0.023)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                for side in [0.0, 0.945] {
                    for i in 0..<30 {
                        var grain = Path()
                        for j in 0...24 {
                            let y = CGFloat(j) / 24 * size.height
                            let x = size.width * (side + Double(i) * 0.0018) + sin(Double(j) * 0.21 + Double(i)) * size.width * 0.0012
                            let point = CGPoint(x: x, y: y)
                            if j == 0 { grain.move(to: point) } else { grain.addLine(to: point) }
                        }
                        context.stroke(grain, with: .color(.black.opacity(Double(i % 4 + 1) * 0.055)), lineWidth: max(0.5, size.width * 0.00065))
                    }
                }
            }
            let colors: [Color] = bright
                ? [Color(white: 0.69), Color(white: 0.40), Color(white: 0.60), Color(white: 0.29)]
                : [Color(white: 0.19), Color(white: 0.065), Color(white: 0.10), Color(white: 0.035)]
            context.fill(Path(roundedRect: panel, cornerRadius: 5), with: .linearGradient(Gradient(colors: colors),
                startPoint: panel.origin, endPoint: CGPoint(x: panel.minX, y: panel.maxY)))
            var metal = context
            metal.clip(to: Path(panel))
            for i in 0..<200 {
                let y = CGFloat(i) / 200 * panel.height
                var line = Path(); line.move(to: CGPoint(x: panel.minX, y: y)); line.addLine(to: CGPoint(x: panel.maxX, y: y))
                metal.stroke(line, with: .color((i % 3 == 0 ? Color.white : .black).opacity(bright ? 0.07 : 0.08)), lineWidth: 0.5)
            }
            context.stroke(Path(roundedRect: panel.insetBy(dx: 1, dy: 1), cornerRadius: 5),
                with: .linearGradient(Gradient(colors: [.white.opacity(0.45), .black, .white.opacity(0.18)]),
                startPoint: panel.origin, endPoint: CGPoint(x: panel.maxX, y: panel.maxY)), lineWidth: 2)
            let screwRadius = min(size.width * 0.0048, size.height * 0.017)
            for x in [panel.minX + screwRadius * 2.8, panel.maxX - screwRadius * 2.8] {
                for y in [panel.minY + screwRadius * 2.8, panel.maxY - screwRadius * 2.8] {
                    HardwareDrawing.screw(context, center: CGPoint(x: x, y: y), radius: screwRadius)
                }
            }
        }
    }
}

enum HardwareDrawing {
    static func screw(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [Color(white: 0.55), .black, Color(white: 0.25)]),
            startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: max(0.5, radius * 0.12))
        var slot = Path(); slot.move(to: CGPoint(x: center.x - radius * 0.60, y: center.y + radius * 0.23))
        slot.addLine(to: CGPoint(x: center.x + radius * 0.60, y: center.y - radius * 0.23))
        context.stroke(slot, with: .color(.black), lineWidth: radius * 0.30)
    }

    static func lamp(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, lit: Bool) {
        let socket = CGRect(x: center.x - radius * 1.4, y: center.y - radius * 1.4, width: radius * 2.8, height: radius * 2.8)
        context.fill(Path(ellipseIn: socket), with: .color(.black))
        context.stroke(Path(ellipseIn: socket), with: .color(Color(white: 0.28)), lineWidth: radius * 0.2)
        if lit {
            var glow = context; glow.addFilter(.blur(radius: radius * 1.7))
            glow.fill(Path(ellipseIn: socket), with: .color(color.opacity(0.50)))
        }
        let bulb = socket.insetBy(dx: radius * 0.4, dy: radius * 0.4)
        context.fill(Path(ellipseIn: bulb), with: .radialGradient(Gradient(colors: [lit ? color : color.opacity(0.18), .black]),
            center: CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.30), startRadius: 0, endRadius: radius * 1.6))
        let glint = CGRect(x: center.x - radius * 0.45, y: center.y - radius * 0.60, width: radius * 0.65, height: radius * 0.36)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(lit ? 0.7 : 0.15)))
    }
}
