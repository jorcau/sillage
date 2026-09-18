import SwiftUI

enum SillageBrand {
    static let mint = Color(red: 0.48, green: 0.87, blue: 0.73)
}

/// Original waveform geometry shared by the dashboard and generated app icon.
struct SillageMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 240
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let envelope = pow(sin(.pi * t), 2)
            let wave = sin(6 * .pi * t) * envelope
            let point = CGPoint(x: rect.minX + rect.width * t,
                                y: rect.midY - rect.height * 0.48 * wave)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
