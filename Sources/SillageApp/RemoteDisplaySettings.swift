import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins
import AudioAnalysis
import RemoteDisplay

@MainActor
final class RemoteDisplayModel: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var ready = false
    @Published private(set) var viewers = 0
    @Published private(set) var error: String?
    @Published private(set) var addresses: [String] = []
    @Published var selectedAddress = ""
    private var port: UInt16 = 8765
    private var key = ""
    private let store: FrameStore
    private let presentation: () -> RemotePresentation
    private var timer: Timer?
    private lazy var server = RemoteDisplayServer(store: store) { [weak self] event in
        Task { @MainActor in self?.receive(event) }
    }

    init(store: FrameStore, presentation: @escaping () -> RemotePresentation) {
        self.store = store; self.presentation = presentation
    }

    var link: URL? {
        guard ready, !selectedAddress.isEmpty else { return nil }
        return URL(string: "http://\(selectedAddress):\(port)/#join=\(key)")
    }
    var displayAddress: String { "http://\(selectedAddress):\(port)" }

    func setEnabled(_ value: Bool) {
        guard value != enabled else { return }
        enabled = value; ready = false; error = nil; viewers = 0
        timer?.invalidate(); timer = nil
        if value {
            server.update(presentation()); server.start()
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in guard let self, self.enabled else { return }; self.server.update(self.presentation()) }
            }
        } else { server.stop(); key = ""; addresses = []; selectedAddress = "" }
    }

    private func receive(_ event: RemoteServerEvent) {
        switch event {
        case let .ready(port, addresses, key):
            guard enabled else { return }
            self.port = port; self.addresses = addresses; self.key = key
            self.selectedAddress = addresses.first ?? "127.0.0.1"; ready = true
        case .viewers(let count): viewers = count
        case .failed(let detail): enabled = false; ready = false; error = detail; key = ""; timer?.invalidate(); timer = nil
        case .stopped: break
        }
    }

    var qrImage: NSImage? {
        guard let link else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.absoluteString.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let image = context.createCGImage(output.transformed(by: CGAffineTransform(scaleX: 6, y: 6)), from: output.extent.applying(CGAffineTransform(scaleX: 6, y: 6))) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: 156, height: 156))
    }

    func copyLink() {
        guard let link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.absoluteString, forType: .string)
    }
}

struct RemoteDisplaySettings: View {
    @ObservedObject var remote: RemoteDisplayModel
    @ObservedObject var model: AppModel

    var body: some View {
        Section {
            Toggle(model.text("Share on the local network"), isOn: Binding(get: { remote.enabled }, set: { remote.setEnabled($0) }))
            Text(model.text("Scan the QR code on your phone. Keep your Mac awake and both devices on the same Wi-Fi network. Sound stays on the Mac."))
                .font(.caption).foregroundStyle(.secondary)
            if remote.enabled {
                if remote.ready {
                    HStack(alignment: .center, spacing: 18) {
                        if let image = remote.qrImage {
                            Image(nsImage: image).interpolation(.none).resizable().frame(width: 148, height: 148)
                                .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityLabel(model.text("Scan to open Sillage on your phone"))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.text("Scan to connect")).font(.headline)
                            Text(remote.displayAddress).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            Text(model.localizer.format("%d connected screens", remote.viewers)).font(.caption).foregroundStyle(.secondary)
                            Button(model.text("Copy private link")) { remote.copyLink() }
                            if let link = remote.link { Link(model.text("Open in browser"), destination: link) }
                        }
                    }.padding(.vertical, 6)
                    if remote.addresses.count > 1 {
                        Picker(model.text("Network address"), selection: $remote.selectedAddress) {
                            ForEach(remote.addresses, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if remote.addresses.isEmpty {
                        Text(model.text("No local Wi-Fi or Ethernet address found. Connect the Mac to your network, then restart sharing.")).font(.caption).foregroundStyle(.orange)
                    }
                    Text(model.text("The private link grants viewing access until sharing is stopped. Up to four screens. No internet service is used."))
                        .font(.caption).foregroundStyle(.secondary)
                } else { ProgressView(model.text("Starting local display…")) }
            }
            if let error = remote.error { Text(model.localizer.format("Could not start sharing: %@", error)).font(.caption).foregroundStyle(.orange) }
        } header: { Text(model.text("Phone display")) }
    }
}
