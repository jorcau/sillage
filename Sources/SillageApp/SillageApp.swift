import SwiftUI
import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
            CommandGroup(after: .newItem) {
                Button("Écouter l’audio système") { Task { await model.startSystem() } }.keyboardShortcut("r", modifiers: .command)
                Button("Mettre en pause") { Task { await model.stop() } }.keyboardShortcut(".", modifiers: .command)
                Button("Démo silencieuse") { Task { await model.startDemo() } }.keyboardShortcut("d", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Plein écran") { model.toggleFullscreen() }.keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}
