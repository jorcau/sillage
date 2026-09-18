import AppKit
import SwiftUI
import AudioAnalysis
import SystemCapture

@MainActor
final class AppModel: ObservableObject {
    enum Mode { case idle, system, demo }
    let store = FrameStore()
    let displayMetrics = DisplayMetrics()
    lazy var pipeline = AnalysisPipeline(store: store)
    lazy var capture = SystemAudioCapture { [weak self] in
        Task { @MainActor in await self?.configurationChanged() }
    }
    private var pipe: AudioPipe?
    @Published var mode = Mode.idle
    @Published var busy = false
    @Published var message = "Prêt à écouter"
    @Published var error: String?
    @Published var deviceName = "Sortie audio inchangée"
    @Published var demoSignal = DemoSignal.music
    @Published var brightness = 0.68
    @Published var showPeaks = true
    @Published var protectOLED = true
    @Published var targetFPS = 60
    private var started = Date()
    private var connectionAttempt = UUID()

    func startSystem() async {
        guard !busy else { return }
        busy = true; error = nil; message = "Connexion au son système…"
        let attempt = UUID()
        connectionAttempt = attempt
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.busy, self.connectionAttempt == attempt else { return }
            self.message = "En attente de macOS…"
            self.error = "La connexion attend une réponse du système. Si une demande de capture audio est affichée, répondez-y, puis réessayez si nécessaire."
        }
        await stopResources()
        let newPipe = AudioPipe()
        pipe = newPipe
        do {
            let info = try await capture.start(ringAddress: UInt(bitPattern: newPipe.pointer))
            pipeline.start(pipe: newPipe, sampleRate: info.sampleRate)
            deviceName = info.outputName
            error = nil
            mode = .system; message = "Audio système"; started = Date()
        } catch {
            self.error = error.localizedDescription
            mode = .idle; message = "Capture indisponible"; pipe = nil
        }
        busy = false
    }
    func startDemo(_ signal: DemoSignal = .music) async {
        guard !busy else { return }
        busy = true; error = nil
        await stopResources()
        demoSignal = signal
        pipeline.start(pipe: nil, sampleRate: 48_000, demo: signal)
        mode = .demo; message = "Démo silencieuse"; deviceName = signal.rawValue
        started = Date(); busy = false
    }
    func stop() async {
        guard !busy else { return }
        busy = true; await stopResources()
        store.publish(AnalysisFrame())
        message = "En pause"; busy = false
    }
    func shutdown() async { await stopResources() }
    private func stopResources() async {
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
        if mode == .system && frame.callbacks == 0 && Date().timeIntervalSince(started) > 3 {
            return "En attente d’audio · vérifiez l’autorisation macOS"
        }
        if frame.invalidBuffers > 0 { return "Format du flux modifié · reconnectez la capture" }
        return message
    }
    func toggleFullscreen() { NSApp.keyWindow?.toggleFullScreen(nil) }
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
