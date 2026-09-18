import SwiftUI
import AudioAnalysis
import AppLocalization

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker(model.text("Language"), selection: $model.language) {
                    Text(model.text("System")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("Français").tag(AppLanguage.french)
                }
                Text(model.text("Applies immediately. System follows your preferred macOS language, with English as the fallback."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text(model.text("General")) }

            Section {
                Picker(model.text("Signal"), selection: Binding(
                    get: { model.demoSignal },
                    set: { signal in
                        if model.mode == .demo {
                            Task { await model.startDemo(signal) }
                        } else {
                            model.demoSignal = signal
                        }
                    }
                )) {
                    ForEach(DemoSignal.allCases, id: \.self) { signal in
                        Text(model.text(signal.rawValue)).tag(signal)
                    }
                }.disabled(model.busy)
                Text(model.text("Generated in memory. No sound is played. Starting a preview pauses system audio capture."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.text(model.mode == .demo ? "Stop preview" : "Start preview")) {
                        Task {
                            if model.mode == .demo { await model.stop() }
                            else { await model.startDemo(model.demoSignal) }
                        }
                    }
                    Button(model.text("Listen to system audio")) { Task { await model.startSystem() } }
                        .disabled(model.mode == .system)
                    Spacer()
                    if model.mode == .demo {
                        SillageMark().stroke(Palette.mint, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                            .frame(width: 20, height: 16)
                            .accessibilityLabel(model.text("Preview running"))
                    }
                }.disabled(model.busy)
            } header: { Text(model.text("Demo previews")) }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 330)
        .preferredColorScheme(.dark)
    }
}
