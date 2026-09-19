import Foundation

public struct StereoPoint: Sendable { public var x: Float; public var y: Float }
public struct WaveformColumn: Sendable {
    public var leftMin: Float
    public var leftMax: Float
    public var rightMin: Float
    public var rightMax: Float
}
public struct ChannelLevel: Sendable {
    public var rmsDB: Float = -90
    public var peakDB: Float = -90
    public var holdDB: Float = -90
    public var clipped = false
    public init() {}
}
public struct AnalysisFrame: Sendable {
    public var left = ChannelLevel()
    public var right = ChannelLevel()
    public var spectrum: [Float] = Array(repeating: -90, count: 160)
    public var spectrumHold: [Float] = Array(repeating: -90, count: 160)
    public var phase: [StereoPoint] = []
    public var waveform: [WaveformColumn] = []
    public var waveformDuration: Double = 0.020
    public var leftPPMDB: Float = -90
    public var rightPPMDB: Float = -90
    public var correlation: Float = 0
    public var sampleRate: Double = 48_000
    /// Monotonic time of actual input consumption. Synthesized meter decay never updates this.
    public var lastInputTime: TimeInterval?
    public func hasRecentInput(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard let lastInputTime, time.isFinite, lastInputTime.isFinite else { return false }
        return (0...2).contains(time - lastInputTime)
    }
    public var processedFrames: UInt64 = 0
    public var droppedFrames: UInt64 = 0
    public var callbacks: UInt64 = 0
    public var invalidBuffers: UInt64 = 0
    public var analysisMS: Double = 0
    public init() {}
}

// Only the analysis queue writes. The UI reads one immutable snapshot per display tick.
public final class FrameStore: @unchecked Sendable {
    private let lock = NSLock()
    private var frame = AnalysisFrame()
    public init() {}
    public func publish(_ next: AnalysisFrame) { lock.lock(); frame = next; lock.unlock() }
    public func read() -> AnalysisFrame { lock.lock(); defer { lock.unlock() }; return frame }
}
