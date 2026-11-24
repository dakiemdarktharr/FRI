import Darwin
import Foundation
import Network
import Security

// Resolve once and use the checked numeric address for the TCP connection. The original
// hostname remains the TLS identity. Redirects are never followed.
public enum PublicCalendarSource {
    public static func read(_ input: String) async throws -> String {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.utf8.count <= 2048,
              let parts = URLComponents(string: input), let url = parts.url,
              parts.scheme?.lowercased() == "https",
              let host = url.host(), !host.isEmpty, !host.hasSuffix("."),
              url.user == nil, url.password == nil, url.fragment == nil,
              url.port == nil || url.port == 443,
              !host.utf8.contains(where: { $0 <= 32 || $0 >= 127 }) else { throw Failure.invalidURL }

        let path = parts.percentEncodedPath.isEmpty ? "/" : parts.percentEncodedPath
        let target = path + (parts.percentEncodedQuery.map { "?" + $0 } ?? "")
        let hostHeader = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        let request = Data("""
        GET \(target) HTTP/1.1\r
        Host: \(hostHeader)\r
        Accept: text/calendar, application/ld+json, text/html, text/plain\r
        Accept-Encoding: identity\r
        User-Agent: FRI Calendar Import\r
        Connection: close\r
        \r

        """.utf8)

        let addresses = try await Task.detached { try resolve(host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) }.value
        try Task.checkCancellation()
        var payload: Data?
        for address in addresses.prefix(3) {
            do {
                let exchange = HTTPSExchange(address: address, host: host, request: request)
                payload = try await exchange.read()
                break
            } catch let error as NWError {
                if case .tls = error { throw error }
            }
        }
        guard let payload else { throw Failure.network }
        return try decodeResponse(payload)
    }

    static func isPublic(_ string: String) -> Bool {
        if let ip = IPv4Address(string) {
            let octets = Array(ip.rawValue)
            let first = octets[0], second = octets[1], third = octets[2]
            return !(
                first == 0 || first == 10 || first == 127 || first >= 224 ||
                (first == 100 && (64...127).contains(second)) ||
                (first == 169 && second == 254) || (first == 172 && (16...31).contains(second)) ||
                (first == 192 && (second == 168 || second == 0 || (second == 88 && third == 99))) ||
                (first == 198 && (second == 18 || second == 19 || (second == 51 && third == 100))) ||
                (first == 203 && second == 0 && third == 113)
            )
        }
        if let ip = IPv6Address(string) {
            let octets = Array(ip.rawValue)
            guard !string.contains("%"), (0x20...0x3f).contains(octets[0]) else { return false }
            if octets[0] == 0x20 {
                if octets[1] == 0x02 { return false }
                if octets[1] == 0x01 && (octets[2] < 2 || (octets[2] == 0x0d && octets[3] == 0xb8)) { return false }
            }
            return !(octets[0] == 0x3f && octets[1] == 0xff)
        }
        return false
    }

    private static func resolve(_ host: String) throws -> [String] {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        hints.ai_family = AF_UNSPEC
        hints.ai_protocol = IPPROTO_TCP
        var head: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &head) == 0, let head else { throw Failure.network }
        defer { freeaddrinfo(head) }
        var next: UnsafeMutablePointer<addrinfo>? = head
        var addresses: [String] = []
        while let pointer = next {
            let item = pointer.pointee
            next = item.ai_next
            var bytes = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(item.ai_addr, item.ai_addrlen, &bytes, socklen_t(bytes.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { throw Failure.network }
            let string = String(decoding: bytes.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard isPublic(string) else { throw Failure.privateNetwork }
            if !addresses.contains(string) { addresses.append(string) }
        }
        guard !addresses.isEmpty else { throw Failure.network }
        return addresses
    }

    static func decodeResponse(_ response: Data) throws -> String {
        let separator = Data([13, 10, 13, 10])
        guard let split = response.range(of: separator), split.lowerBound <= 32_768,
              let head = String(data: response[..<split.lowerBound], encoding: .utf8) else { throw Failure.network }
        let lines = head.components(separatedBy: "\r\n")
        guard let status = lines.first?.split(separator: " "), status.count >= 2,
              status[0] == "HTTP/1.1" || status[0] == "HTTP/1.0",
              let code = Int(status[1]), (200..<300).contains(code) else { throw Failure.badStatus }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw Failure.network }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces).lowercased()
            if ["content-length", "transfer-encoding", "content-encoding"].contains(name), headers[name] != nil { throw Failure.network }
            headers[name] = value
        }
        guard headers["content-encoding"] == nil || headers["content-encoding"] == "identity" else { throw Failure.network }
        let body = Data(response[split.upperBound...])
        let payload: Data
        if let transfer = headers["transfer-encoding"] {
            guard transfer == "chunked", headers["content-length"] == nil else { throw Failure.network }
            payload = try unchunk(body)
        } else {
            if let length = headers["content-length"], Int(length) != body.count { throw Failure.network }
            payload = body
        }
        guard payload.count <= 1_048_576 else { throw Failure.limit }
        guard let text = String(data: payload, encoding: .utf8) else { throw Failure.network }
        return text
    }

    private static func unchunk(_ data: Data) throws -> Data {
        let newline = Data([13, 10])
        var cursor = data.startIndex
        var result = Data()
        while let boundary = data.range(of: newline, in: cursor..<data.endIndex) {
            let length = data[cursor..<boundary.lowerBound].prefix(while: { $0 != 59 })
            guard length.count <= 8, let size = Int(String(decoding: length, as: UTF8.self), radix: 16), size >= 0 else {
                throw Failure.network
            }
            if size == 0 { return result }
            guard size <= 1_048_576 - result.count else { throw Failure.limit }
            let first = boundary.upperBound
            let last = first + size
            guard last + 2 <= data.endIndex, data[last..<last + 2].elementsEqual(newline) else { throw Failure.network }
            result.append(data[first..<last])
            cursor = last + 2
        }
        throw Failure.network
    }

    enum Failure: LocalizedError {
        case invalidURL, privateNetwork, network, badStatus, limit

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Use a direct public HTTPS calendar link."
            case .privateNetwork: "FRI cannot read links on private or local networks."
            case .network: "FRI could not read the source. Download the calendar file and import it instead."
            case .badStatus: "This link redirects, requires sign-in or is unavailable."
            case .limit: "Calendar sources must be under 1 MB."
            }
        }
    }
}

private final class HTTPSExchange: @unchecked Sendable {
    private let queue = DispatchQueue(label: "FRI.PublicCalendar")
    private let connection: NWConnection
    private let request: Data
    private var receiver: CheckedContinuation<Data, any Error>?
    private var response = Data()
    private var cancelled = false

    init(address: String, host: String, request: Data) {
        self.request = request
        let identity = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, identity)
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, complete in
            let appleTrust = sec_trust_copy_ref(trust).takeRetainedValue()
            let policy = SecPolicyCreateSSL(true, identity as CFString)
            let configured = SecTrustSetPolicies(appleTrust, policy) == errSecSuccess
            complete(configured && SecTrustEvaluateWithError(appleTrust, nil))
        }, queue)
        connection = NWConnection(host: NWEndpoint.Host(address), port: .https,
                                  using: NWParameters(tls: options, tcp: NWProtocolTCP.Options()))
    }

    func read() async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { receiver in
                queue.async { [self] in
                    guard !self.cancelled else { receiver.resume(throwing: CancellationError()); return }
                    self.receiver = receiver
                    self.connection.stateUpdateHandler = { [weak self] state in
                        switch state {
                        case .ready: self?.send()
                        case .failed(let error), .waiting(let error): self?.finish(.failure(error))
                        default: break
                        }
                    }
                    self.connection.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                        self?.finish(.failure(PublicCalendarSource.Failure.network))
                    }
                }
            }
        } onCancel: {
            queue.async {
                self.cancelled = true
                self.finish(.failure(CancellationError()))
            }
        }
    }

    private func send() {
        connection.send(content: request, completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(.failure(error)) }
            else { self?.receive() }
        })
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { [weak self] data, _, done, error in
            guard let self, self.receiver != nil else { return }
            if let error { self.finish(.failure(error)); return }
            if let data { self.response.append(data) }
            if self.response.count > 1_179_648 {
                self.finish(.failure(PublicCalendarSource.Failure.limit))
            } else if done {
                self.finish(.success(self.response))
            } else { self.receive() }
        }
    }

    private func finish(_ result: Result<Data, any Error>) {
        guard let receiver else { return }
        self.receiver = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        receiver.resume(with: result)
    }
}
