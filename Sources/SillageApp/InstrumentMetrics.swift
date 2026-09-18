import SwiftUI

// Scale layout and type before drawing; never magnify a rasterized Canvas/view layer.
struct InstrumentMetrics: Sendable {
    var scale: CGFloat = 1
    var displayScale: CGFloat = 1

    func snap(_ points: CGFloat) -> CGFloat {
        (points * displayScale).rounded() / displayScale
    }
    func size(_ points: CGFloat) -> CGFloat { snap(points * scale) }
    var hairline: CGFloat { 1 / displayScale }
    func strokeCenter(_ points: CGFloat, width: CGFloat) -> CGFloat {
        let pixels = max(1, (width * displayScale).rounded())
        let offset: CGFloat = Int(pixels) % 2 == 0 ? 0 : 0.5
        return ((points * displayScale).rounded(.down) + offset) / displayScale
    }
}

private struct InstrumentMetricsKey: EnvironmentKey {
    static let defaultValue = InstrumentMetrics()
}
extension EnvironmentValues {
    var instrumentMetrics: InstrumentMetrics {
        get { self[InstrumentMetricsKey.self] }
        set { self[InstrumentMetricsKey.self] = newValue }
    }
}
