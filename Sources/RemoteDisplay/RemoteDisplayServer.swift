import Foundation
@preconcurrency import Network
import AudioAnalysis

public enum RemoteServerEvent: Sendable {
    case ready(port: UInt16, addresses: [String], key: String)
    case viewers(Int)
    case failed(String)
    case stopped
}

/// All network state is confined to queue. Slow viewers drop snapshots, never block DSP.
public final class RemoteDisplayServer: @unchecked Sendable {
    private final class Peer: @unchecked Sendable {
        let id = UUID()
        let connection: NWConnection
        var request = Data()
        var streaming = false
        var pending = false
        var sentAt: TimeInterval = 0
        init(_ connection: NWConnection) { self.connection = connection }
    }
    private let queue = DispatchQueue(label: "audio.sillage.remote", qos: .userInitiated)
    private let store: FrameStore
    private let event: @Sendable (RemoteServerEvent) -> Void
    private var listener: NWListener?
    private var timer: DispatchSourceTimer?
    private var peers: [UUID: Peer] = [:]
    private var sessions: Set<String> = []
    private var key = ""
    private var hosts: Set<String> = []
    private var presentation = RemotePresentation()
    private var sequence: UInt64 = 0
    private var failedPairings = 0
    private var pairingWindow = Date.distantPast
    private let encoder = JSONEncoder()
    // A packaged macOS app keeps SwiftPM bundles in Contents/Resources. Never
    // fall back to the developer's build directory when serving the installed app.
    private static let webRoot: URL? = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.resourceURL?.appendingPathComponent("Sillage_RemoteDisplay.bundle/Web", isDirectory: true)
        }
        return Bundle.module.url(forResource: "Web", withExtension: nil)
    }()

    public init(store: FrameStore, event: @escaping @Sendable (RemoteServerEvent) -> Void) {
        self.store = store; self.event = event
    }

    public func update(_ state: RemotePresentation) { queue.async { self.presentation = state } }

    public func start(port: UInt16 = 8765) {
        queue.async { [self] in
            guard self.listener == nil else { return }
            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true
                let listener = try NWListener(using: parameters, on: port == 0 ? .any : NWEndpoint.Port(rawValue: port)!)
                self.listener = listener
                self.key = Self.randomKey()
                self.failedPairings = 0; self.pairingWindow = Date()
                listener.stateUpdateHandler = { [weak self, weak listener] state in
                    guard let self, let listener, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port?.rawValue else { return }
                        let addresses = LocalAddresses.ipv4()
                        self.hosts = Set((addresses + ["localhost", "127.0.0.1", "[::1]"]).map { "\($0):\(port)" })
                        self.event(.ready(port: port, addresses: addresses, key: self.key))
                        self.startTimer()
                    case .failed(let error): self.stopOnQueue(); self.event(.failed(error.localizedDescription))
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self] in self?.accept($0) }
                listener.start(queue: self.queue)
            } catch { self.stopOnQueue(); self.event(.failed(error.localizedDescription)) }
        }
    }

    public func stop() { queue.async { self.stopOnQueue(); self.event(.stopped) } }

    private func stopOnQueue() {
        timer?.cancel(); timer = nil
        listener?.stateUpdateHandler = nil; listener?.cancel(); listener = nil
        for peer in peers.values { peer.connection.stateUpdateHandler = nil; peer.connection.cancel() }
        peers.removeAll(); sessions.removeAll(); hosts.removeAll(); key = ""
    }

    private static func randomKey() -> String { (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased() }

    private func accept(_ connection: NWConnection) {
        guard peers.count < 32, case .hostPort(let host, _) = connection.endpoint,
              LocalAddresses.isPrivate(String(describing: host)) else { connection.cancel(); return }
        let peer = Peer(connection); peers[peer.id] = peer
        connection.stateUpdateHandler = { [weak self, weak peer] state in
            guard let self, let peer else { return }
            switch state {
            case .ready: self.receive(peer)
            case .failed, .cancelled: self.remove(peer)
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 10) { [weak self, weak peer] in
            guard let self, let peer, !peer.streaming else { return }; self.remove(peer)
        }
    }

    private func receive(_ peer: Peer) {
        peer.connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self, weak peer] data, _, complete, error in
            guard let self, let peer, self.peers[peer.id] != nil else { return }
            if let data, !data.isEmpty {
                if peer.streaming { self.remove(peer); return }
                peer.request.append(data)
                do {
                    if let request = try HTTPRequest.parse(peer.request) {
                        peer.request.removeAll()
                        self.route(request, peer)
                        if peer.streaming { self.receive(peer) }
                        return
                    }
                } catch { self.respond(peer, status: "400 Bad Request"); return }
            }
            if complete || error != nil { self.remove(peer) } else { self.receive(peer) }
        }
    }

    private func route(_ request: HTTPRequest, _ peer: Peer) {
        guard request.permits(hosts: hosts) else { respond(peer, status: "403 Forbidden"); return }
        if request.method == "POST", request.path == "/api/pair" {
            if Date().timeIntervalSince(pairingWindow) > 60 { pairingWindow = Date(); failedPairings = 0 }
            guard failedPairings < 20, sessions.count < 32 else { respond(peer, status: "429 Too Many Requests"); return }
            struct Pairing: Decodable { let key: String }
            guard let pairing = try? JSONDecoder().decode(Pairing.self, from: request.body), pairing.key == key, !key.isEmpty else {
                failedPairings += 1; respond(peer, status: "403 Forbidden"); return
            }
            let session = Self.randomKey(); sessions.insert(session)
            respond(peer, status: "204 No Content", headers: ["Set-Cookie": "sillage_viewer=\(session); Path=/api; HttpOnly; SameSite=Strict"])
            return
        }
        guard request.method == "GET" else { respond(peer, status: "405 Method Not Allowed"); return }
        if request.path == "/api/stream" || request.path == "/api/session" {
            guard let session = request.session, sessions.contains(session) else { respond(peer, status: "401 Unauthorized"); return }
            if request.path == "/api/session" { respond(peer, status: "204 No Content"); return }
            guard peers.values.filter(\.streaming).count < 4 else { respond(peer, status: "429 Too Many Requests"); return }
            peer.streaming = true; peer.pending = true; peer.sentAt = ProcessInfo.processInfo.systemUptime
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\nretry: 1500\n\n"
            peer.connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self, weak peer] error in
                guard let self, let peer else { return }; peer.pending = false
                if error != nil { self.remove(peer) }
            })
            event(.viewers(peers.values.filter(\.streaming).count))
            return
        }
        let files = ["/": "index.html", "/index.html": "index.html", "/app.js": "app.js", "/renderer.js": "renderer.js",
                     "/styles.css": "styles.css", "/locales/en.json": "locales/en.json", "/locales/fr.json": "locales/fr.json",
                     "/manifest.webmanifest": "manifest.webmanifest", "/sw.js": "sw.js", "/icon.svg": "icon.svg",
                     "/icon-192.png": "icon-192.png", "/icon-512.png": "icon-512.png", "/apple-touch-icon.png": "apple-touch-icon.png"]
        guard let name = files[request.path], let root = Self.webRoot,
              let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { respond(peer, status: "404 Not Found"); return }
        let ext = (name as NSString).pathExtension
        let mime = ["html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
                    "json": "application/json", "webmanifest": "application/manifest+json", "svg": "image/svg+xml", "png": "image/png"][ext] ?? "application/octet-stream"
        respond(peer, status: "200 OK", body: data, headers: ["Content-Type": mime])
    }

    private func respond(_ peer: Peer, status: String, body: Data = Data(), headers: [String: String] = [:]) {
        var response = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nX-Frame-Options: DENY\r\nContent-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; worker-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'\r\n"
        for (key, value) in headers { response += "\(key): \(value)\r\n" }
        var data = Data((response + "\r\n").utf8); data.append(body)
        peer.connection.send(content: data, completion: .contentProcessed { [weak self, weak peer] _ in
            guard let self, let peer else { return }; self.remove(peer)
        })
    }

    private func remove(_ peer: Peer) {
        guard peers.removeValue(forKey: peer.id) != nil else { return }
        peer.connection.stateUpdateHandler = nil; peer.connection.cancel()
        if peer.streaming { event(.viewers(peers.values.filter(\.streaming).count)) }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(3))
        timer.setEventHandler { [weak self] in self?.broadcast() }
        self.timer = timer; timer.resume()
    }

    private func broadcast() {
        let viewers = peers.values.filter(\.streaming)
        guard !viewers.isEmpty else { return }
        sequence &+= 1
        let frame = store.read()
        guard let json = try? encoder.encode(DisplayPacket(frame: frame, presentation: presentation, sequence: sequence)) else { return }
        var data = Data("data: ".utf8); data.append(json); data.append(Data("\n\n".utf8))
        for peer in viewers {
            let now = ProcessInfo.processInfo.systemUptime
            if peer.pending {
                if now - peer.sentAt > 5 { remove(peer) }
                continue
            }
            peer.pending = true; peer.sentAt = now
            peer.connection.send(content: data, completion: .contentProcessed { [weak self, weak peer] error in
                guard let self, let peer else { return }; peer.pending = false
                if error != nil { self.remove(peer) }
            })
        }
    }
}
