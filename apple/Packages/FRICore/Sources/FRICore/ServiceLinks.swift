import Foundation

public enum ServiceLinks {
    public static func spotify(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "open.spotify.com", url.user == nil, url.password == nil,
              url.port == nil,
              url.path.range(of: #"^/(playlist|album|track|episode)/[A-Za-z0-9]+$"#, options: .regularExpression) != nil
        else { return nil }
        var canonical = URLComponents()
        canonical.scheme = "https"
        canonical.host = "open.spotify.com"
        canonical.path = url.path
        return canonical.url
    }
}
