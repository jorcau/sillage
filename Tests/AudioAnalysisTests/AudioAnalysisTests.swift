import Testing
import Foundation
import AudioAnalysis
import CRealtime

@Suite(.serialized)
struct AudioAnalysisTests {
    private func feed(_ analyzer: AudioAnalyzer, seconds: Double = 2, frequency: Double = 1000, amplitude: Float = 0.5, rightGain: Float = 1) {
        let n = Int(analyzer.sampleRate * seconds)
        var offset = 0
        while offset < n {
            let count = min(512, n-offset)
            let l = (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double(offset+$0) / analyzer.sampleRate)) }
            let r = l.map { $0 * rightGain }
            analyzer.process(left: l, right: r, count: count)
            offset += count
        }
    }
    @Test func testSineRMSAndPeakCalibration() {
        let analyzer = AudioAnalyzer(sampleRate: 48000)
        feed(analyzer)
        expectEqual(analyzer.frame.left.rmsDB, -9.0309, accuracy: 0.06)
        expectEqual(analyzer.frame.left.peakDB, -6.0206, accuracy: 0.02)
        expectEqual(analyzer.frame.correlation, 1, accuracy: 0.0001)
    }
    @Test func testFFTCoherentGainAndLogFrequency() {
        for sampleRate in [44100.0, 48000, 96000] {
            let analyzer = AudioAnalyzer(sampleRate: sampleRate)
            let frequency = sampleRate * 171 / Double(AudioAnalyzer.fftSize) // Exact FFT bin.
            feed(analyzer, frequency: frequency)
            let maximum = analyzer.frame.spectrum.max()!
            expectEqual(maximum, -6.0206, accuracy: 0.06)
            let band = analyzer.frame.spectrum.firstIndex(of: maximum)!
            let center = 20 * pow(1000, (Double(band)+0.5) / 160)
            expectEqual(center / frequency, 1, accuracy: 0.08)
        }
    }
    @Test func testAntiphaseDoesNotDisappearFromSpectrum() {
        let analyzer = AudioAnalyzer(sampleRate: 48000)
        feed(analyzer, rightGain: -1)
        expectEqual(analyzer.frame.correlation, -1, accuracy: 0.0001)
        expectGreater(analyzer.frame.spectrum.max()!, -8)
        expectTrue(analyzer.frame.phase.allSatisfy { abs($0.y) < 1e-7 })
        expectGreater(analyzer.frame.phase.map { abs($0.x) }.max()!, 0.49)
    }
    @Test func testMonoIsVerticalAndSingleChannelIsIndependent() {
        let mono = AudioAnalyzer(sampleRate: 48000)
        feed(mono)
        expectTrue(mono.frame.phase.allSatisfy { abs($0.x) < 1e-7 })
        let solo = AudioAnalyzer(sampleRate: 48000)
        feed(solo, rightGain: 0)
        expectEqual(solo.frame.right.rmsDB, -90, accuracy: 0.01)
        expectEqual(solo.frame.right.peakDB, -90, accuracy: 0.01)
        expectEqual(solo.frame.correlation, 0, accuracy: 0.001)
    }
    @Test func testSilenceAndPeakHoldReleaseAreFinite() {
        let analyzer = AudioAnalyzer(sampleRate: 48000)
        feed(analyzer)
        feed(analyzer, seconds: 0.5, amplitude: 0)
        expectEqual(analyzer.frame.left.holdDB, -6.0206, accuracy: 0.02)
        feed(analyzer, seconds: 5, amplitude: 0)
        expectLess(analyzer.frame.left.holdDB, -60)
        expectLess(analyzer.frame.left.rmsDB, -80)
        expectTrue(analyzer.frame.spectrum.allSatisfy { $0.isFinite && $0 < -85 })
    }
    @Test func testClippingLatchClears() {
        let analyzer = AudioAnalyzer(sampleRate: 48000)
        feed(analyzer, seconds: 0.1, amplitude: 1.1)
        expectTrue(analyzer.frame.left.clipped)
        feed(analyzer, seconds: 3, amplitude: 0)
        expectFalse(analyzer.frame.left.clipped)
    }
    @Test func testLowAndHighFrequencyCoverage() {
        for hz in [23.4375, 19000] {
            let analyzer = AudioAnalyzer(sampleRate: 48000)
            feed(analyzer, frequency: hz)
            let band = analyzer.frame.spectrum.firstIndex(of: analyzer.frame.spectrum.max()!)!
            if hz < 30 { expectLess(band, 10) }
            else { expectGreater(band, 155) }
            expectGreater(analyzer.frame.spectrum.max()!, -9)
        }
    }
    @Test func testRingWrapOverflowAndSanitization() {
        let ring = nt_ring_create(8)!
        defer { nt_ring_destroy(ring) }
        var outL = [Float](repeating: 0, count: 8), outR = outL
        let l: [Float] = [1, 2, 3, 4, 5, 6], r: [Float] = [-1, -2, -3, -4, -5, -6]
        expectEqual(nt_ring_write(ring, l, r, 6, 1), 6)
        expectEqual(nt_ring_read(ring, &outL, &outR, 4), 4)
        expectEqual(Array(outL.prefix(4)), [1,2,3,4])
        expectEqual(nt_ring_write(ring, l, r, 6, 1), 6)
        expectEqual(nt_ring_write(ring, l, r, 6, 1), 0)
        expectEqual(nt_ring_dropped(ring), 6)
        expectEqual(nt_ring_read(ring, &outL, &outR, 8), 8)
        expectEqual(outL, [5,6,1,2,3,4,5,6])
        expectEqual(outR, [-5,-6,-1,-2,-3,-4,-5,-6])
        expectEqual(nt_ring_write(ring, [Float.nan], [Float.infinity], 1, 1), 1)
        expectEqual(nt_ring_read(ring, &outL, &outR, 1), 1)
        expectEqual(outL[0], 0); expectEqual(outR[0], 0)
    }
    @Test func testInterleavedRingInput() {
        let ring = nt_ring_create(8)!
        defer { nt_ring_destroy(ring) }
        let input: [Float] = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3]
        input.withUnsafeBufferPointer { p in
            expectEqual(nt_ring_write(ring, p.baseAddress!, p.baseAddress!+1, 3, 2), 3)
        }
        var l = [Float](repeating: 0, count: 3), r = l
        expectEqual(nt_ring_read(ring, &l, &r, 3), 3)
        expectEqual(l, [0.1,0.2,0.3]); expectEqual(r, [-0.1,-0.2,-0.3])
    }
    @Test func testRealtimeAnalysisBudget() {
        let analyzer = AudioAnalyzer(sampleRate: 48000)
        let start = ProcessInfo.processInfo.systemUptime
        feed(analyzer, seconds: 5)
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        print(String(format: "DSP benchmark: 5 s of stereo audio processed in %.3f s (%.2f%% of realtime).", elapsed, elapsed / 5 * 100))
        expectLess(elapsed, 5, "Analysis must keep up with real time")
    }
}

private func expectEqual<T: Equatable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a == b, sourceLocation: sourceLocation)
}
private func expectEqual<T: BinaryFloatingPoint>(_ a: T, _ b: T, accuracy: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(a - b) <= accuracy, sourceLocation: sourceLocation)
}
private func expectGreater<T: Comparable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a > b, sourceLocation: sourceLocation)
}
private func expectLess<T: Comparable>(_ a: T, _ b: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a < b, Comment(rawValue: message), sourceLocation: sourceLocation)
}
private func expectTrue(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value, sourceLocation: sourceLocation)
}
private func expectFalse(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!value, sourceLocation: sourceLocation)
}
