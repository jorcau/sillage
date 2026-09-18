import Foundation
import CRealtime

// Stable lifetime shared by the HAL and analysis queue. Reset only by creating a new pipe.
public final class AudioPipe: @unchecked Sendable {
    public let pointer: OpaquePointer
    public init() { guard let p = nt_ring_create(65536) else { fatalError("Audio buffer allocation failed") }; pointer = p }
    deinit { nt_ring_destroy(pointer) }
}

public enum DemoSignal: String, CaseIterable, Sendable {
    case music = "Music", mono = "Mono · 1 kHz", antiphase = "Antiphase", left = "Left only", silence = "Silence"
}

public final class AnalysisPipeline: @unchecked Sendable {
    public let store: FrameStore
    private let queue = DispatchQueue(label: "audio.sillage.analysis", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var analyzer: AudioAnalyzer?
    private var pipe: AudioPipe?
    private var demo: DemoSignal?
    private var demoPosition: UInt64 = 0
    private var left = [Float](repeating: 0, count: 4096)
    private var right = [Float](repeating: 0, count: 4096)
    private var lastData = ProcessInfo.processInfo.systemUptime
    public init(store: FrameStore) { self.store = store }

    public func start(pipe: AudioPipe?, sampleRate: Double, demo: DemoSignal? = nil) {
        queue.sync {
            self.timer?.cancel()
            self.pipe = pipe; self.demo = demo; self.demoPosition = 0
            self.analyzer = AudioAnalyzer(sampleRate: sampleRate)
            self.lastData = ProcessInfo.processInfo.systemUptime
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }
    public func stop() {
        queue.sync { timer?.cancel(); timer = nil; pipe = nil; analyzer = nil; demo = nil }
    }
    private func tick() {
        guard let analyzer else { return }
        let start = ProcessInfo.processInfo.systemUptime
        if let demo {
            let n = 384 // 48 kHz * 8 ms. Demo is analysis-only: nothing goes to speakers.
            for i in 0..<n {
                let t = Double(demoPosition + UInt64(i)) / 48_000
                let tone = Float(sin(2 * Double.pi * 1000 * t)) * 0.5
                switch demo {
                case .mono: left[i] = tone; right[i] = tone
                case .antiphase: left[i] = tone; right[i] = -tone
                case .left: left[i] = tone; right[i] = 0
                case .silence: left[i] = 0; right[i] = 0
                case .music:
                    var a = 0.0, b = 0.0
                    for (j, f) in [41.2, 65.41, 98, 146.83, 220, 329.63, 493.88, 740, 1108.73, 1661.22, 2489, 3729, 5588, 8372, 12543].enumerated() {
                        let envelope = 0.45 + 0.55 * pow(sin(t * 0.8 + Double(j) * 0.6), 2)
                        let amplitude = 0.16 * envelope / pow(Double(j+1), 0.48)
                        a += amplitude * sin(2 * .pi * f * t)
                        b += amplitude * sin(2 * .pi * f * t + 1.1 * sin(t * 0.3 + Double(j)))
                    }
                    left[i] = Float(a); right[i] = Float(b)
                }
            }
            demoPosition += UInt64(n)
            analyzer.process(left: left, right: right, count: n)
        } else if let pipe {
            var total = 0
            // Bounded drain: recover without allowing an unbounded work item to starve stop().
            for _ in 0..<16 {
                let n = Int(nt_ring_read(pipe.pointer, &left, &right, 4096))
                if n == 0 { break }
                analyzer.process(left: left, right: right, count: n)
                total += n
            }
            if total > 0 { lastData = start }
            else if start - lastData > 0.08 {
                // Some HAL devices stop delivering buffers during silence. Decay stale meters.
                let n = min(4096, Int(analyzer.sampleRate * 0.008))
                for i in 0..<n { left[i] = 0; right[i] = 0 }
                analyzer.process(left: left, right: right, count: n)
            }
        }
        var frame = analyzer.frame
        frame.analysisMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
        if let pipe {
            frame.droppedFrames = nt_ring_dropped(pipe.pointer)
            frame.callbacks = nt_ring_callbacks(pipe.pointer)
            frame.invalidBuffers = nt_ring_invalid(pipe.pointer)
        }
        store.publish(frame)
    }
    deinit { timer?.cancel() }
}
