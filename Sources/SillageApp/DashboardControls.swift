import SwiftUI
import AppKit
import AudioAnalysis

/// One stable control group, outside the instruments' animation timeline.
struct DashboardControls: View {
    @ObservedObject var model: AppModel
    let frame: AnalysisFrame
    @Environment(\.instrumentMetrics) private var metrics
    @Environment(\.instrumentTheme) private var theme
    private func m(_ value: CGFloat) -> CGFloat { metrics.size(value) }

    var body: some View {
        HStack(spacing: m(6)) {
            viewMenu
            audioStatus
            SettingsLink { Image(systemName: "gearshape").frame(width: m(18)) }
                .buttonStyle(HeaderControlStyle())
                .help(model.text("Settings") + " · ⌘,")
                .accessibilityLabel(model.text("Settings"))
            Button {
                Task { if model.mode == .system { await model.stop() } else { await model.startSystem() } }
            } label: {
                Label(model.text(model.busy ? "Connecting…" : model.mode == .system ? "Pause" : "Listen"),
                      systemImage: model.mode == .system ? "pause.fill" : "play.fill")
                    .frame(minWidth: m(62))
            }
            .buttonStyle(HeaderControlStyle(emphasized: true)).disabled(model.busy)
            Button { model.toggleFullscreen() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: m(18))
            }
            .buttonStyle(HeaderControlStyle())
            .help(model.text("Full Screen") + " · ⌃⌘F")
            .accessibilityLabel(model.text("Full Screen"))
        }
        .padding(m(6))
        .background(Color(white: 0.025), in: RoundedRectangle(cornerRadius: m(12)))
        .overlay(RoundedRectangle(cornerRadius: m(12)).strokeBorder(Color(white: 0.10), lineWidth: metrics.hairline))
    }

    private var sourceTitle: String {
        model.mode == .demo && !model.busy ? model.text("Silent demo") : model.audioSummary(frame: frame)
    }

    private var audioStatus: some View {
        let hasIssues = frame.droppedFrames > 0 || frame.invalidBuffers > 0
        let isReceiving = !model.busy && model.mode != .idle && frame.hasRecentInput()
        return HStack(spacing: m(9)) {
            Circle().fill(hasIssues ? InterfaceColors.amber : isReceiving ? theme.accent : InterfaceColors.secondary)
                .frame(width: m(5), height: m(5))
            VStack(alignment: .leading, spacing: m(3)) {
                Text(sourceTitle).font(.system(size: m(11), weight: .medium)).monospacedDigit()
                    .foregroundStyle(Color(white: 0.82))
                Text(model.displayedDeviceName).font(.system(size: m(10)))
                    .foregroundStyle(InterfaceColors.secondary)
            }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: m(194), height: m(42))
        .padding(.horizontal, m(12))
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: m(8)))
        .help(model.status(frame: frame) + "\n" + model.displayedDeviceName)
        .accessibilityElement(children: .combine)
    }

    private var viewMenu: some View {
        HStack(spacing: m(8)) {
            Image(systemName: model.layout.symbol).font(.system(size: m(13)))
            Text(model.text(model.layout.title)).lineLimit(1)
            Spacer(minLength: m(4))
            Image(systemName: "chevron.down").font(.system(size: m(8), weight: .semibold)).foregroundStyle(.secondary)
        }
        .font(.system(size: m(11), weight: .medium))
        .foregroundStyle(Color(white: 0.82))
        .frame(width: m(138), height: m(42))
        .padding(.horizontal, m(12))
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: m(8)))
        .accessibilityHidden(true)
        .overlay { NativeViewSelector(model: model) }
    }
}

/// Keep native menu tracking and keyboard/accessibility behavior, with a shared visual surface.
private struct NativeViewSelector: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isTransparent = true
        button.isBordered = false
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectView(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.model = model
        let layouts = VisualizerLayout.allCases
        let titles = layouts.map { model.text($0.title) }
        // Never rebuild an open menu for incoming analysis frames.
        if button.itemTitles != titles {
            button.removeAllItems()
            for (layout, title) in zip(layouts, titles) {
                button.addItem(withTitle: title)
                button.lastItem?.representedObject = layout.rawValue
            }
        }
        if button.selectedItem?.representedObject as? String != model.layout.rawValue,
           let index = layouts.firstIndex(of: model.layout) { button.selectItem(at: index) }
        button.setAccessibilityLabel(model.text("View"))
        button.toolTip = model.text("Choose a view") + " · ⌘1–9 / ⌘0 / ⌘−"
    }

    @MainActor final class Coordinator: NSObject {
        var model: AppModel
        init(model: AppModel) { self.model = model }
        @objc func selectView(_ sender: NSPopUpButton) {
            guard let value = sender.selectedItem?.representedObject as? String,
                  let layout = VisualizerLayout(rawValue: value) else { return }
            model.layout = layout
        }
    }
}

struct HeaderControlStyle: ButtonStyle {
    var emphasized = false
    @Environment(\.instrumentMetrics) private var metrics
    @Environment(\.instrumentTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: metrics.size(12), weight: .medium))
            .foregroundStyle(emphasized ? theme.accent : Color(white: 0.82))
            .padding(.horizontal, metrics.size(12))
            .frame(height: metrics.size(42))
            .background(emphasized ? theme.accent.opacity(configuration.isPressed ? 0.24 : 0.12)
                : Color(white: configuration.isPressed ? 0.10 : 0.055),
                in: RoundedRectangle(cornerRadius: metrics.size(8)))
            .contentShape(RoundedRectangle(cornerRadius: metrics.size(8)))
    }
}
