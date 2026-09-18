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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(InstrumentTheme.allCases, id: \.self) { theme in
                        themeButton(theme)
                    }
                }
                Text(model.text("Applies instantly to instruments and controls. Your choice is saved."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text(model.text("Themes")) }

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
                        SillageMark().stroke(model.theme.accent, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                            .frame(width: 20, height: 16)
                            .accessibilityLabel(model.text("Preview running"))
                    }
                }.disabled(model.busy)
            } header: { Text(model.text("Demo previews")) }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 690)
        .tint(model.theme.accent)
        .preferredColorScheme(.dark)
    }

    private func themeButton(_ theme: InstrumentTheme) -> some View {
        let selected = model.theme == theme
        return Button { model.theme = theme } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text(model.text(theme.title)).font(.system(size: 11, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent).opacity(selected ? 1 : 0)
                }
                LinearGradient(colors: theme.colors, startPoint: theme.spectrumStart, endPoint: theme.spectrumEnd)
                    .frame(height: 26)
                    .mask {
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array([0.3, 0.6, 0.9, 0.5, 0.75, 0.4].enumerated()), id: \.offset) { _, level in
                                VStack(spacing: 3) {
                                    Rectangle().frame(height: 1)
                                    Rectangle().opacity(0.75).frame(height: 22 * level)
                                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                    }
                Label(model.text(theme.spectrumDescription), systemImage: theme.spectrumAxis == .level ? "arrow.up" : "arrow.right")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(10).frame(maxWidth: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? theme.accent : Color(white: 0.22), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.text(theme.title))
        .accessibilityValue(model.text(theme.spectrumDescription))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
