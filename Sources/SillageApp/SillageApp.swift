import SwiftUI
import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task { await model.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

@main
struct SillageApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Sillage", id: "main") {
            Dashboard(model: model)
                .environment(\.appLocalizer, model.localizer)
                .frame(minWidth: 980, minHeight: 620)
                .preferredColorScheme(.dark)
                .onAppear {
                    delegate.model = model
                    if ProcessInfo.processInfo.arguments.contains("--demo") { Task { await model.startDemo() } }
                }
        }
        .defaultSize(width: 1400, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text(model.text("Settings…")) }.keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button(model.text("Listen to system audio")) { Task { await model.startSystem() } }.keyboardShortcut("r", modifiers: .command)
                Button(model.text("Pause capture")) { Task { await model.stop() } }.keyboardShortcut(".", modifiers: .command)
                SettingsLink { Text(model.text("Demo previews…")) }.keyboardShortcut("d", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                ForEach(VisualizerLayout.allCases, id: \.self) { layout in
                    Button(model.text(layout.title)) { model.layout = layout }
                        .keyboardShortcut(layout.shortcut, modifiers: .command)
                }
                Divider()
                Button(model.text("Full Screen")) { model.toggleFullscreen() }.keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
        Settings { SettingsView(model: model) }
    }
}
