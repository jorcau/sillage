import Accelerate
import Foundation

// Queue-confined streaming analyzer. No calls to this class occur in the HAL callback.
public final class AudioAnalyzer {
    public static let fftSize = 8192
    public static let hopSize = 1024
    public static let bandCount = 160
    public let sampleRate: Double
    private let setup: FFTSetup
    private let log2n = vDSP_Length(13)
    private var historyL = [Float](repeating: 0, count: fftSize)
    private var historyR = [Float](repeating: 0, count: fftSize)
    private var window = [Float](repeating: 0, count: fftSize)
    private var real = [Float](repeating: 0, count: fftSize)
    private var imaginary = [Float](repeating: 0, count: fftSize)
    private var power = [Float](repeating: 0, count: fftSize / 2)
    private var leftPower = [Float](repeating: 0, count: fftSize / 2)
    private var linear = [Float](repeating: 0, count: fftSize)
    private var position = 0
    private var hop = 0
    private var count: UInt64 = 0
    private var rmsL: Float = 0
    private var rmsR: Float = 0
    private var cross: Float = 0
    private var energyL: Float = 0
    private var energyR: Float = 0
    private var levelHoldTime: [Double] = [0, 0]
    private var clipTime: [Double] = [0, 0]
    private var bandHoldTime = [Double](repeating: 0, count: bandCount)
    private var bandRanges: [(Int, Int)] = []
    private var scale: Float = 1
    public private(set) var frame = AnalysisFrame()

    public init(sampleRate: Double) {
        precondition(sampleRate >= 8_000 && sampleRate.isFinite)
        self.sampleRate = sampleRate
        guard let fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { fatalError("FFT allocation failed") }
        setup = fft
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        var sum: Float = 0
        vDSP_sve(window, 1, &sum, vDSP_Length(Self.fftSize))
        scale = 4 / (sum * sum) // Complex FFT: peak amplitude squared, coherent Hann gain corrected.
        frame.sampleRate = sampleRate
        for i in 0..<Self.bandCount {
            let lo = 20 * pow(1000, Double(i) / Double(Self.bandCount))
            let hi = 20 * pow(1000, Double(i + 1) / Double(Self.bandCount))
            let a = max(1, Int((lo * Double(Self.fftSize) / sampleRate).rounded()))
            let b = max(a, Int((hi * Double(Self.fftSize) / sampleRate).rounded()))
            bandRanges.append((a, min(Self.fftSize / 2 - 1, b)))
        }
    }
    deinit { vDSP_destroy_fftsetup(setup) }

    public func process(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count n: Int) {
        guard n > 0 else { return }
        let dt = Double(n) / sampleRate
        var msL: Float = 0, msR: Float = 0, dot: Float = 0, peakL: Float = 0, peakR: Float = 0
        vDSP_measqv(left, 1, &msL, vDSP_Length(n)); vDSP_measqv(right, 1, &msR, vDSP_Length(n))
        vDSP_dotpr(left, 1, right, 1, &dot, vDSP_Length(n))
        vDSP_maxmgv(left, 1, &peakL, vDSP_Length(n)); vDSP_maxmgv(right, 1, &peakR, vDSP_Length(n))
        let rmsAlpha = Float(1 - exp(-dt / 0.3))
        rmsL += rmsAlpha * (msL - rmsL); rmsR += rmsAlpha * (msR - rmsR)
        let corrAlpha = Float(1 - exp(-dt / 0.15))
        cross += corrAlpha * (dot / Float(n) - cross)
        energyL += corrAlpha * (msL - energyL); energyR += corrAlpha * (msR - energyR)
        frame.left = level(rms: rmsL, peak: peakL, old: frame.left, channel: 0, dt: dt)
        frame.right = level(rms: rmsR, peak: peakR, old: frame.right, channel: 1, dt: dt)
        let denominator = sqrt(energyL * energyR)
        frame.correlation = denominator > 1e-10 ? max(-1, min(1, cross / denominator)) : 0
        for i in 0..<n {
            historyL[position] = left[i]; historyR[position] = right[i]
            position = (position + 1) & (Self.fftSize - 1)
            count += 1; hop += 1
            if hop >= Self.hopSize {
                hop = 0
                if count >= Self.fftSize { analyzeSpectrum() }
            }
        }
        // Fixed-size, recent phase trail; mono vertical, antiphase horizontal. No auto-gain.
        let available = min(Int(count), 2048)
        var points: [StereoPoint] = []
        points.reserveCapacity(1024)
        for i in stride(from: 0, to: available, by: 2) {
            let idx = (position - available + i + Self.fftSize) & (Self.fftSize - 1)
            let l = historyL[idx], r = historyR[idx]
            points.append(StereoPoint(x: (l-r) * 0.5, y: (l+r) * 0.5))
        }
        frame.phase = points
        frame.processedFrames = count
    }

    private func level(rms: Float, peak: Float, old: ChannelLevel, channel: Int, dt: Double) -> ChannelLevel {
        var next = old
        next.rmsDB = Self.dbPower(rms)
        let peakDB = Self.dbAmplitude(peak)
        next.peakDB = max(peakDB, old.peakDB - Float(dt * 22))
        if peakDB >= old.holdDB { next.holdDB = peakDB; levelHoldTime[channel] = 1.5 }
        else {
            levelHoldTime[channel] -= dt
            if levelHoldTime[channel] <= 0 { next.holdDB = max(next.peakDB, old.holdDB - Float(dt * 18)) }
        }
        if peak >= 1 { clipTime[channel] = 2 } else { clipTime[channel] = max(0, clipTime[channel] - dt) }
        next.clipped = clipTime[channel] > 0
        return next
    }

    private func fft(_ history: [Float]) {
        for i in 0..<Self.fftSize { linear[i] = history[(position + i) & (Self.fftSize - 1)] }
        vDSP_vmul(linear, 1, window, 1, &real, 1, vDSP_Length(Self.fftSize))
        vDSP_vclr(&imaginary, 1, vDSP_Length(Self.fftSize))
        real.withUnsafeMutableBufferPointer { re in
            imaginary.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(Self.fftSize / 2))
            }
        }
    }

    private func analyzeSpectrum() {
        fft(historyL)
        // Copy into dedicated storage, rather than sharing a copy-on-write buffer with the next FFT.
        for i in 0..<power.count { leftPower[i] = power[i] }
        fft(historyR)
        let dt = Double(Self.hopSize) / sampleRate
        for i in 0..<Self.bandCount {
            let (a, b) = bandRanges[i]
            var maximum: Float = 0
            if a <= b {
                for bin in a...b { maximum = max(maximum, (leftPower[bin] + power[bin]) * 0.5 * scale) }
            }
            let target = Self.dbPower(maximum)
            let old = frame.spectrum[i]
            let alpha = Float(1 - exp(-dt / (target > old ? 0.028 : 0.20)))
            frame.spectrum[i] = old + alpha * (target - old)
            if target >= frame.spectrumHold[i] { frame.spectrumHold[i] = target; bandHoldTime[i] = 1.5 }
            else {
                bandHoldTime[i] -= dt
                if bandHoldTime[i] <= 0 { frame.spectrumHold[i] = max(frame.spectrum[i], frame.spectrumHold[i] - Float(dt * 12)) }
            }
        }
    }
    public static func dbAmplitude(_ value: Float) -> Float { max(-90, 20 * log10(max(value, 0.0000316228))) }
    public static func dbPower(_ value: Float) -> Float { max(-90, 10 * log10(max(value, 1e-9))) }
}
