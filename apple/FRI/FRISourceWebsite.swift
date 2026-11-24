import CryptoKit
import FRICore
import SwiftUI
import WebKit

/// The user navigates and signs in themselves. Only an explicit read on the source's origin returns visible text.
@MainActor
final class SourceWebsite: NSObject, WKNavigationDelegate, Identifiable {
    let url: URL
    let webView: WKWebView
    let id = UUID()

    init(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else {
            throw SourceFailure("Enter an HTTPS website address without credentials.")
        }
        self.url = url
        let digest = SHA256.hash(data: Data(host.utf8))
        let identifier = digest.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: identifier)
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let dest = action.request.url, dest.scheme == "https", dest.user == nil, dest.password == nil else { return .cancel }
        if action.targetFrame?.isMainFrame == true, !(await PublicCalendarSource.permitsWebsite(dest)) { return .cancel }
        return .allow
    }

    func read() async throws -> String {
        guard !webView.isLoading, webView.url?.host?.lowercased() == url.host?.lowercased(),
              webView.url?.port == url.port else { throw SourceFailure("Return to the calendar website and wait for it to finish loading.") }
        let script = """
            if (location.origin !== origin || document.querySelector('input[type=password]')) return null;
            return (document.body?.innerText || '').slice(0, 60000);
            """
        let origin = "https://" + (url.host?.lowercased() ?? "")
        let result = try await webView.callAsyncJavaScript(script, arguments: ["origin": origin], in: nil, contentWorld: .defaultClient)
        guard let text = result as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SourceFailure("Open your timetable after signing in, then read it again.")
        }
        return text
    }

    func disconnect() async {
        webView.stopLoading()
        await webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
}

#if os(macOS)
private struct SourcePage: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#else
private struct SourcePage: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif

private struct SourceAddress: View {
    let webView: WKWebView
    @State private var address = ""
    var body: some View {
        Text(address).font(.caption).lineLimit(1)
            .onReceive(webView.publisher(for: \.url)) { address = $0?.host ?? "" }
    }
}

struct FRISourceWebsiteView: View {
    let source: SourceWebsite
    let useText: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedback = ""
    var body: some View {
        FRISheetView(title: source.url.host ?? "Source website") {
            VStack {
                SourceAddress(webView: source.webView)
                SourcePage(webView: source.webView)
                if !feedback.isEmpty { Text(feedback).font(.caption) }
                HStack {
                    Button("Disconnect") { Task { await source.disconnect(); dismiss() } }
                    Spacer()
                    Button("Use visible text") {
                        Task {
                            do { let text = try await source.read(); useText(text); dismiss() }
                            catch { feedback = error.localizedDescription }
                        }
                    }.buttonStyle(.borderedProminent)
                }.padding()
            }
        }
    }
}
