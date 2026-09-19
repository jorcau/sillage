import AppKit
import SwiftUI
import AudioAnalysis
import SystemCapture
import AppLocalization
import RemoteDisplay

@MainActor
final class AppModel: ObservableObject {
    enum Mode { case idle, system, demo }
    let store = FrameStore()
    let displayMetrics = DisplayMetrics()
    lazy var remoteDisplay = RemoteDisplayModel(store: store) { [weak self] in
        guard let self else { return RemotePresentation() }
        let source = self.busy ? "waiting" : self.mode == .demo ? "demo" : self.mode == .system
            ? (self.store.read().hasRecentInput() ? "system" : "waiting") : "paused"
        return RemotePresentation(view: self.layout.rawValue, theme: self.theme.rawValue, source: source)
    }
    lazy var pipeline = AnalysisPipeline(store: store)
    lazy var capture = SystemAudioCapture { [weak self] in
        Task { @MainActor in await self?.configurationChanged() }
    }
    private var pipe: AudioPipe?
    @Published var mode = Mode.idle
    @Published var busy = false
    @Published var message = "Ready to listen"
    @Published var error: String?
    @Published private var captureFailure: CaptureError?
    @Published private(set) var captureInfo: CaptureInfo?
    @Published var language: AppLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    // Read the previous preference as a fallback so existing selections survive the rename.
    @Published var theme = InstrumentTheme(savedValue: UserDefaults.standard.string(forKey: "theme")
        ?? UserDefaults.standard.string(forKey: "colorPalette")) {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    @Published var layout = VisualizerLayout(rawValue: UserDefaults.standard.string(forKey: "visualizerLayout") ?? "") ?? .dashboard {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: "visualizerLayout") }
    }
    @Published var deviceName = "Audio output unchanged"
    @Published var demoSignal = DemoSignal.music
    @Published var brightness = 1.0
    @Published var showPeaks = true
    @Published var protectOLED = true
    @Published var targetFPS = 60
    private var connectionAttempt = UUID()

    var localizer: AppLocalizer { AppLocalizer(language: language) }
    func text(_ key: String) -> String { localizer.text(key) }
    var displayedDeviceName: String { mode == .demo ? text(demoSignal.rawValue) : text(deviceName) }
    var displayedError: String? {
        if let captureFailure {
            switch captureFailure {
            case let .osStatus(operation, code):
                return localizer.format("%@: Core Audio error %d. Check audio capture permission in System Settings → Privacy & Security.", text(operation), code)
            case .unsupportedFormat:
                return text("Unsupported capture format: stereo Float32 PCM is required.")
            }
        }
        return error.map(text)
    }

    func startSystem() async {
        guard !busy else { return }
        busy = true; error = nil; captureFailure = nil; message = "Connecting to system audio…"
        let attempt = UUID()
        connectionAttempt = attempt
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.busy, self.connectionAttempt == attempt else { return }
            self.message = "Waiting for macOS…"
            self.error = "Waiting for the system to respond. If an audio capture permission prompt is shown, respond to it, then retry if needed."
        }
        await stopResources()
        let newPipe = AudioPipe()
        pipe = newPipe
        do {
            let info = try await capture.start(ringAddress: UInt(bitPattern: newPipe.pointer))
            captureInfo = info
            pipeline.start(pipe: newPipe, sampleRate: info.sampleRate)
            deviceName = info.outputName
            error = nil
            mode = .system; message = "System audio"
        } catch {
            captureFailure = error as? CaptureError
            self.error = error.localizedDescription
            mode = .idle; message = "Capture unavailable"; pipe = nil
        }
        busy = false
    }
    func startDemo(_ signal: DemoSignal = .music) async {
        guard !busy else { return }
        busy = true; error = nil; captureFailure = nil
        await stopResources()
        demoSignal = signal
        pipeline.start(pipe: nil, sampleRate: AnalysisPipeline.demoSampleRate, demo: signal)
        mode = .demo; message = "Silent demo"; deviceName = signal.rawValue
        busy = false
    }
    func stop() async {
        guard !busy else { return }
        busy = true; await stopResources()
        store.publish(AnalysisFrame())
        message = "Paused"; error = nil; captureFailure = nil; busy = false
    }
    func shutdown() async { remoteDisplay.setEnabled(false); await stopResources() }
    private func stopResources() async {
        captureInfo = nil
        await capture.stop()
        pipeline.stop()
        store.publish(AnalysisFrame())
        pipe = nil; mode = .idle
    }
    private func configurationChanged() async {
        guard mode == .system, !busy else { return }
        await startSystem()
    }
    func status(frame: AnalysisFrame) -> String {
        if frame.invalidBuffers > 0 { return text("Audio format changed · reconnect capture") }
        if mode == .system && !busy && !frame.hasRecentInput() { return text("Waiting for audio") }
        return text(message)
    }
    func audioSummary(frame: AnalysisFrame) -> String {
        if busy { return text("Waiting for audio") }
        switch mode {
        case .idle: return text(error == nil ? "Paused" : "Capture unavailable")
        case .demo: return localizer.format("Demo · %@", text(demoSignal.rawValue))
        case .system:
            guard frame.hasRecentInput() else { return text("Waiting for audio") }
            return localizer.format("System audio · %@", sampleRateText(frame.sampleRate))
        }
    }
    func sampleRateText(_ rate: Double) -> String {
        let key = rate.truncatingRemainder(dividingBy: 1000) == 0 ? "%.0f kHz" : "%.1f kHz"
        return localizer.format(key, rate / 1000)
    }
    struct StreamFormat {
        let sampleRate: Double
        let channels: Int
        let bits: Int
    }
    var streamFormat: StreamFormat? {
        guard !busy else { return nil }
        switch mode {
        case .system:
            guard let captureInfo else { return nil }
            return StreamFormat(sampleRate: captureInfo.sampleRate, channels: Int(captureInfo.channelCount), bits: Int(captureInfo.bitsPerChannel))
        case .demo:
            return StreamFormat(sampleRate: AnalysisPipeline.demoSampleRate, channels: AudioAnalyzer.channelCount, bits: MemoryLayout<Float>.size * 8)
        case .idle: return nil
        }
    }
    func toggleFullscreen() { NSApp.windows.first(where: { $0.title == "Sillage" })?.toggleFullScreen(nil) }
    func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") { NSWorkspace.shared.open(url) }
    }
}

@MainActor
final class DisplayMetrics {
    private var start: Date?
    private var count = 0
    private(set) var updatesPerSecond = 0.0
    func tick(_ date: Date) -> Bool {
        guard let start else { self.start = date; return false }
        count += 1
        let interval = date.timeIntervalSince(start)
        guard interval >= 1 else { return false }
        updatesPerSecond = Double(count) / interval
        count = 0; self.start = date
        return true
    }
}
