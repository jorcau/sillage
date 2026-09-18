import Foundation
import AudioAnalysis

public struct RemotePresentation: Codable, Sendable {
    public var view: String
    public var theme: String
    public var source: String
    public init(view: String = "dashboard", theme: String = "mint", source: String = "paused") {
        self.view = view; self.theme = theme; self.source = source
    }
}

/// A versioned, bounded display snapshot. No device names, PCM stream, or metadata.
struct DisplayPacket: Encodable {
    let version = 1
    let sequence: UInt64
    let presentation: RemotePresentation
    let sampleRate: Double
    let levels: [[Float]]
    let clipped: [Bool]
    let spectrum: [Float]
    let hold: [Float]
    let phase: [[Float]]
    let waveform: [[Float]]
    let waveformMS: Double
    let correlation: Float

    init(frame: AnalysisFrame, presentation: RemotePresentation, sequence: UInt64) {
        self.sequence = sequence; self.presentation = presentation
        sampleRate = frame.sampleRate.isFinite ? frame.sampleRate : 48_000
        func bounded(_ value: Float, _ low: Float = -90, _ high: Float = 0) -> Float {
            guard value.isFinite else { return low }
            return (min(high, max(low, value)) * 1_000).rounded() / 1_000
        }
        levels = [[frame.left.rmsDB, frame.left.peakDB, frame.left.holdDB, frame.leftPPMDB],
                  [frame.right.rmsDB, frame.right.peakDB, frame.right.holdDB, frame.rightPPMDB]].map { $0.map { bounded($0, -90, 12) } }
        clipped = [frame.left.clipped, frame.right.clipped]
        spectrum = frame.spectrum.prefix(160).map { bounded($0) }
        hold = frame.spectrumHold.prefix(160).map { bounded($0) }
        let points = frame.phase
        let step = max(1, Int(ceil(Double(points.count) / 256)))
        phase = stride(from: 0, to: points.count, by: step).map { [bounded(points[$0].x, -1, 1), bounded(points[$0].y, -1, 1)] }
        let columns = frame.waveform
        let group = max(1, Int(ceil(Double(columns.count) / 256)))
        waveform = stride(from: 0, to: columns.count, by: group).map { start in
            let slice = columns[start..<min(start + group, columns.count)]
            return [bounded(slice.map(\.leftMin).min() ?? 0, -1, 1), bounded(slice.map(\.leftMax).max() ?? 0, -1, 1),
                    bounded(slice.map(\.rightMin).min() ?? 0, -1, 1), bounded(slice.map(\.rightMax).max() ?? 0, -1, 1)]
        }
        waveformMS = frame.waveformDuration.isFinite ? frame.waveformDuration * 1_000 : 20
        correlation = bounded(frame.correlation, -1, 1)
    }
}
