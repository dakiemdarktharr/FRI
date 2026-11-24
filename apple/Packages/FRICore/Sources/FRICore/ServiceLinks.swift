import Foundation

public enum ServiceLinks {
    public static func spotifyEmbed(_ value: String) -> URL? {
        guard let publicURL = spotify(value) else { return nil }
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        components?.path = "/embed" + publicURL.path
        return components?.url
    }

    public static func spotifyBrowserLink(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && url.port == nil
            && ["open.spotify.com", "accounts.spotify.com"].contains(url.host ?? "")
    }

    // Match desktop/services.cjs. Compiled before any remote page is loaded.
    public static let spotifyContentRules = #"""
    [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https://([a-zA-Z0-9-]+\\.)*spotify\\.com/"},"action":{"type":"ignore-previous-rules"}},
     {"trigger":{"url-filter":"^https://([a-zA-Z0-9-]+\\.)*scdn\\.co/"},"action":{"type":"ignore-previous-rules"}},
     {"trigger":{"url-filter":"^https://([a-zA-Z0-9-]+\\.)*spotifycdn\\.com/"},"action":{"type":"ignore-previous-rules"}},
     {"trigger":{"url-filter":"^https://([a-zA-Z0-9-]+\\.)*spotifycdn\\.net/"},"action":{"type":"ignore-previous-rules"}}]
    """#

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
