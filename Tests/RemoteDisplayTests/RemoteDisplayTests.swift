import Foundation
import Testing
import AudioAnalysis
@testable import RemoteDisplay

@Test func parsesFragmentedRequestsAndRejectsAmbiguousFraming() throws {
    let raw = Data("POST /api/pair HTTP/1.1\r\nHost: localhost:8765\r\nContent-Length: 3\r\n\r\nabc".utf8)
    for count in 0..<raw.count { #expect(try HTTPRequest.parse(Data(raw.prefix(count))) == nil) }
    let request = try #require(try HTTPRequest.parse(raw))
    #expect(request.method == "POST" && request.path == "/api/pair")
    #expect(request.body == Data("abc".utf8))
    for headers in ["Content-Length: -1", "Content-Length: 2049", "Transfer-Encoding: chunked", "Content-Length: 0\r\nContent-Length: 0", "Host: other"] {
        let data = Data("GET / HTTP/1.1\r\nHost: localhost:8765\r\n\(headers)\r\n\r\n".utf8)
        #expect(throws: HTTPRequest.Invalid.self) { try HTTPRequest.parse(data) }
    }
    #expect(throws: HTTPRequest.Invalid.self) { try HTTPRequest.parse(Data(repeating: 65, count: 16_385)) }
    #expect(throws: HTTPRequest.Invalid.self) { try HTTPRequest.parse(raw + Data("extra".utf8)) }
}

@Test func rejectsForeignOriginsAndRebindingHosts() throws {
    func request(_ headers: String) throws -> HTTPRequest {
        try #require(try HTTPRequest.parse(Data("GET /api/stream HTTP/1.1\r\n\(headers)\r\n\r\n".utf8)))
    }
    let hosts: Set<String> = ["localhost:8765"]
    #expect(try request("Host: localhost:8765\r\nOrigin: http://localhost:8765").permits(hosts: hosts))
    #expect(try !request("Host: other.example:8765").permits(hosts: hosts))
    #expect(try !request("Host: localhost:8765\r\nOrigin: https://other.example").permits(hosts: hosts))
    #expect(try !request("Host: localhost:8765\r\nSec-Fetch-Site: cross-site").permits(hosts: hosts))
    #expect(try request("Host: localhost:8765\r\nCookie: unrelated=value; sillage_viewer=secret").session == "secret")
}

@Test func limitsLocalAddressScope() {
    for host in ["127.0.0.1", "10.1.2.3", "172.16.1.2", "172.31.2.3", "192.168.4.5", "169.254.1.2", "::1", "fe80::1%en0", "fd12::1"] {
        #expect(LocalAddresses.isPrivate(host))
    }
    for host in ["8.8.8.8", "172.15.1.2", "172.32.1.2", "192.168.1.999", "2001:4860:4860::8888", "example.com"] {
        #expect(!LocalAddresses.isPrivate(host))
    }
}

@Test func displayPacketPreservesExtremaAndBoundsPayload() throws {
    let analyzer = AudioAnalyzer(sampleRate: 96_000)
    let left = (0..<9600).map { Float(0.5 * sin(2 * Double.pi * 997 * Double($0) / 96_000)) }
    analyzer.process(left: left, right: left.map { -$0 }, count: left.count)
    var frame = analyzer.frame
    frame.spectrum = Array(repeating: .nan, count: 1_000)
    frame.left.rmsDB = .infinity; frame.correlation = .nan
    let packet = DisplayPacket(frame: frame, presentation: RemotePresentation(source: "demo"), sequence: 7)
    #expect(packet.phase.count <= 256 && packet.waveform.count <= 256 && packet.spectrum.count == 160)
    #expect(packet.levels[0][0] == -90 && packet.correlation == -1)
    #expect(packet.waveform.allSatisfy { abs($0[0] + $0[3]) < 0.002 && abs($0[1] + $0[2]) < 0.002 })
    #expect(abs((packet.waveform.map { $0[1] }.max() ?? 0) - 0.5) < 0.005)
    let encoded = try JSONEncoder().encode(packet)
    #expect(encoded.count < 20_000)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["version"] as? Int == 1)
    #expect(object["sequence"] as? Int == 7)
    #expect(object["callbacks"] == nil && object["deviceName"] == nil && object["audio"] == nil)
}
