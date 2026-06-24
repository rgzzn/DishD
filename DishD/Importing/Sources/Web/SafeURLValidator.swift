import Foundation

struct SafeURLValidator: Sendable {
    func validate(_ url: URL) throws -> URL {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              !host.isEmpty
        else {
            throw ImportError.invalidURL
        }

        if host == "localhost"
            || host.hasSuffix(".local")
            || isPrivateIPv4(host)
            || host == "::1"
            || host.hasPrefix("fc")
            || host.hasPrefix("fd")
            || host.hasPrefix("fe80") {
            throw ImportError.unsafeURL
        }
        return url
    }

    private func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        return parts[0] == 10
            || parts[0] == 127
            || (parts[0] == 169 && parts[1] == 254)
            || (parts[0] == 172 && (16...31).contains(parts[1]))
            || (parts[0] == 192 && parts[1] == 168)
    }
}
