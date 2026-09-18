import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    enum Invalid: Error { case request }

    /// Incremental parser for one bounded request per connection. No uploads or pipelining.
    static func parse(_ data: Data) throws -> HTTPRequest? {
        guard data.count <= 18_432 else { throw Invalid.request }
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else {
            if data.count > 16_384 { throw Invalid.request }; return nil
        }
        guard boundary.lowerBound <= 16_384,
              let header = String(data: data[..<boundary.lowerBound], encoding: .utf8) else { throw Invalid.request }
        let lines = header.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ", omittingEmptySubsequences: false)
        guard first.count == 3, first[2] == "HTTP/1.1", first[1].hasPrefix("/"), !first[1].hasPrefix("//") else { throw Invalid.request }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw Invalid.request }
            let key = String(line[..<colon]).lowercased()
            guard !key.isEmpty, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }), headers[key] == nil else { throw Invalid.request }
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["host"] != nil, headers["transfer-encoding"] == nil else { throw Invalid.request }
        let lengthText = headers["content-length"] ?? "0"
        guard !lengthText.isEmpty, lengthText.allSatisfy({ $0.isASCII && $0.isNumber }),
              let length = Int(lengthText), length <= 2_048 else { throw Invalid.request }
        let end = boundary.upperBound + length
        guard data.count >= end else { return nil }
        guard data.count == end else { throw Invalid.request }
        return HTTPRequest(method: String(first[0]), path: String(first[1]), headers: headers,
                           body: Data(data[boundary.upperBound..<end]))
    }

    func permits(hosts: Set<String>) -> Bool {
        guard let host = headers["host"]?.lowercased(), hosts.contains(host) else { return false }
        if let origin = headers["origin"], origin != "http://\(host)" { return false }
        return headers["sec-fetch-site"] != "cross-site"
    }

    var session: String? {
        headers["cookie"]?.split(separator: ";").compactMap { part -> String? in
            let pair = part.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
            return pair.count == 2 && pair[0] == "sillage_viewer" ? String(pair[1]) : nil
        }.first
    }
}
