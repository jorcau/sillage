import Foundation
import Testing
@testable import AudioAnalysis

@Test func quasiPeakBurstAndReturnBallistics() {
    for rate in [44100.0, 48000, 96000] {
        func burst(_ duration: Double) -> Float {
            var meter = QuasiPeakMeter(sampleRate: rate)
            for i in 0..<Int(rate * duration) { meter.process(Float(0.5 * sin(2 * .pi * 5000 * Double(i) / rate))) }
            return meter.decibels
        }
        let steady = burst(1)
        #expect(abs(steady + 6.0206) < 0.35)
        #expect(abs((burst(0.010) - steady) + 2) < 0.6)
        #expect(abs((burst(0.005) - steady) + 4) < 0.8)
        var meter = QuasiPeakMeter(sampleRate: rate)
        for _ in 0..<Int(rate) { meter.process(0.5) }
        let before = meter.decibels
        for _ in 0..<Int(rate * 2.8) { meter.process(0) }
        #expect(abs((meter.decibels - before) + 24) < 0.1)
        meter.process(.nan); meter.process(.infinity)
        #expect(meter.decibels.isFinite)
    }
}

@Test func waveformPreservesStereoPolarityScaleAndWindow() {
    for rate in [44100.0, 48000, 96000] {
        let analyzer = AudioAnalyzer(sampleRate: rate)
        let total = Int(rate * 0.1)
        let left = (0..<total).map { Float(0.5 * sin(2 * .pi * 1000 * Double($0) / rate)) }
        let right = left.map { -$0 }
        analyzer.process(left: left, right: right, count: total)
        let trace = analyzer.frame.waveform
        #expect(!trace.isEmpty && trace.count <= 1024)
        #expect(abs(analyzer.frame.waveformDuration - 0.020) < 1 / rate)
        #expect(trace.allSatisfy { abs($0.leftMax + $0.rightMin) < 0.00001 && abs($0.leftMin + $0.rightMax) < 0.00001 })
        #expect(abs((trace.map(\.leftMax).max() ?? 0) - 0.5) < 0.015)
        #expect(abs(analyzer.frame.leftPPMDB - analyzer.frame.rightPPMDB) < 0.001)
        let silence = [Float](repeating: 0, count: total)
        analyzer.process(left: silence, right: silence, count: total)
        #expect(analyzer.frame.waveform.allSatisfy { $0.leftMin == 0 && $0.leftMax == 0 && $0.rightMin == 0 && $0.rightMax == 0 })
    }
}

@Test func quasiPeakIsIndependentOfProcessingBlockSize() {
    let rate = 48000.0
    let samples = (0..<4800).map { Float(0.6 * sin(2 * .pi * 997 * Double($0) / rate)) }
    let silence = [Float](repeating: 0, count: samples.count)
    let whole = AudioAnalyzer(sampleRate: rate)
    whole.process(left: samples, right: silence, count: samples.count)
    let chunked = AudioAnalyzer(sampleRate: rate)
    samples.withUnsafeBufferPointer { left in
        silence.withUnsafeBufferPointer { right in
            for offset in stride(from: 0, to: samples.count, by: 127) {
                chunked.process(left: left.baseAddress! + offset, right: right.baseAddress! + offset, count: min(127, samples.count - offset))
            }
        }
    }
    #expect(abs(whole.frame.leftPPMDB - chunked.frame.leftPPMDB) < 0.0001)
    #expect(abs(chunked.frame.rightPPMDB + 90) < 0.0001)
}
