import Foundation
import Testing
import CRealtime
@testable import AudioAnalysis

@Test func inputActivityExpiresWithoutConfusingSilenceWithMissingInput() {
    var frame = AnalysisFrame()
    #expect(!frame.hasRecentInput(at: 100))
    frame.lastInputTime = 100
    #expect(frame.hasRecentInput(at: 100))
    #expect(frame.hasRecentInput(at: 102))
    #expect(!frame.hasRecentInput(at: 102.001))
    #expect(!frame.hasRecentInput(at: 99))
    #expect(!frame.hasRecentInput(at: .nan))
    #expect(frame.left.peakDB == -90) // Digital silence still counts as real input.
    frame.lastInputTime = .infinity
    #expect(!frame.hasRecentInput(at: 100))
}

@Test func pipelineDistinguishesReceivedSilenceFromSyntheticDecayAndResetsOnRestart() async throws {
    let store = FrameStore()
    let pipeline = AnalysisPipeline(store: store)
    let pipe = AudioPipe()
    defer { pipeline.stop() }
    pipeline.start(pipe: pipe, sampleRate: 44_100)
    // With no captured input the pipeline generates zeros to decay the instruments.
    let empty = try await waitForFrame(store) { $0.processedFrames > 0 }
    #expect(empty.sampleRate == 44_100)
    #expect(empty.lastInputTime == nil)
    #expect(!empty.hasRecentInput())

    let silence = [Float](repeating: 0, count: 384)
    #expect(nt_ring_write(pipe.pointer, silence, silence, 384, 1) == 384)
    let received = try await waitForFrame(store) { $0.lastInputTime != nil }
    #expect(received.hasRecentInput())
    #expect(abs(received.left.peakDB + 90) < 0.001 && abs(received.right.peakDB + 90) < 0.001)

    pipeline.stop()
    pipeline.start(pipe: AudioPipe(), sampleRate: 96_000)
    let restarted = try await waitForFrame(store) { $0.sampleRate == 96_000 }
    #expect(restarted.lastInputTime == nil)

    pipeline.stop()
    pipeline.start(pipe: nil, sampleRate: AnalysisPipeline.demoSampleRate, demo: .silence)
    let demo = try await waitForFrame(store) { $0.sampleRate == AnalysisPipeline.demoSampleRate && $0.lastInputTime != nil }
    #expect(demo.hasRecentInput())
    #expect(abs(demo.left.peakDB + 90) < 0.001)
}

private func waitForFrame(_ store: FrameStore, matching predicate: (AnalysisFrame) -> Bool) async throws -> AnalysisFrame {
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    while ProcessInfo.processInfo.systemUptime < deadline {
        let frame = store.read()
        if predicate(frame) { return frame }
        try await Task.sleep(for: .milliseconds(10))
    }
    let frame = store.read()
    try #require(predicate(frame), "The analysis pipeline did not publish the expected frame")
    return frame
}
