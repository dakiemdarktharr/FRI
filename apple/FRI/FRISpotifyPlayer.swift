import FRICore
import FRIDesign
import SwiftUI
import WebKit

/// A provider-only browser: no calendar bridge, shared cookies or persistent website data.
@MainActor @Observable
final class FRISpotifyPlayer: NSObject, WKNavigationDelegate, WKUIDelegate {
    private(set) var webView: WKWebView?
    private(set) var resourceURL: URL?
    var largeText = false
    private(set) var loading = false
    private(set) var error: String?
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    #if os(macOS)
    @ObservationIgnored private var window: NSWindow?
    #endif

    func open(_ url: URL) {
        guard let canonical = ServiceLinks.spotify(url.absoluteString) else { return }
        if resourceURL == canonical, webView != nil, error == nil { return }
        load(canonical)
    }

    func retry() {
        if let resourceURL { load(resourceURL) }
    }

    private func load(_ url: URL) {
        stop()
        resourceURL = url
        loading = true
        let request = generation
        preparation = Task { [weak self] in
            do {
                let rules = try await WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "FRI.Spotify.ProviderOnly.v1", encodedContentRuleList: ServiceLinks.spotifyContentRules)
                try Task.checkCancellation()
                guard let self, self.generation == request else { return }
                guard let rules, let embed = ServiceLinks.spotifyEmbed(url.absoluteString) else {
                    throw CocoaError(.coderInvalidValue)
                }
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()
                configuration.userContentController.add(rules)
                configuration.mediaTypesRequiringUserActionForPlayback = .all
                #if os(iOS)
                configuration.allowsInlineMediaPlayback = true
                #endif
                let browser = WKWebView(frame: .zero, configuration: configuration)
                browser.navigationDelegate = self
                browser.uiDelegate = self
                browser.allowsLinkPreview = false
                self.webView = browser
                browser.load(URLRequest(url: embed, timeoutInterval: 20))
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.loading = false
                self.error = "Spotify could not load. Check your connection and try again."
            }
        }
    }

    func stop() {
        generation = UUID()
        preparation?.cancel()
        preparation = nil
        if let webView {
            webView.pauseAllMediaPlayback(completionHandler: nil)
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.loadHTMLString("", baseURL: nil)
        }
        webView = nil
        resourceURL = nil
        loading = false
        error = nil
    }

    func close() {
        #if os(macOS)
        window?.close()
        #endif
        stop()
    }

    #if os(macOS)
    func present(onDisconnect: @escaping () -> Void) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        panel.title = "Spotify · FRI"
        panel.minSize = NSSize(width: 360, height: 440)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FRISpotifyPlayerView(player: self, onClose: { [weak self] in self?.close() }, onDisconnect: onDisconnect))
        panel.center()
        window = panel
        panel.makeKeyAndOrderFront(nil)
    }
    #endif

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard webView === self.webView, let url = action.request.url else { decisionHandler(.cancel); return }
        // The embed may navigate its own frames, but may not become a general-purpose browser.
        if let resourceURL, let embed = ServiceLinks.spotifyEmbed(resourceURL.absoluteString),
           url.scheme == "https", url.host == embed.host, url.port == nil,
           url.user == nil, url.password == nil, url.path == embed.path, action.targetFrame != nil {
            decisionHandler(.allow)
            return
        }
        if action.navigationType == .linkActivated, ServiceLinks.spotifyBrowserLink(url) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            failed(webView)
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        loading = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(webView, error: error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(webView, error: error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed(webView) }
    private func failed(_ browser: WKWebView, error: Error? = nil) {
        guard browser === webView else { return }
        if let error, (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == NSURLErrorCancelled { return }
        loading = false
        self.error = "Spotify could not load. Check your connection and try again."
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    @available(macOS 27.0, iOS 27.0, *)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    #if os(iOS)
    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    #endif
}

#if os(macOS)
extension FRISpotifyPlayer: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stop()
        window?.contentView = nil
        window = nil
    }
}
#endif

struct FRISpotifyPlayerView: View {
    let player: FRISpotifyPlayer
    let onClose: () -> Void
    let onDisconnect: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Listen with Spotify").friFont(.headline)
                    Spacer()
                    Button("Close", action: onClose).accessibilityIdentifier("fri.spotify.close")
                }
                Text("Playback is provided by Spotify and depends on your account and region.")
                    .friFont(.caption).foregroundStyle(.secondary)
                if player.loading { ProgressView("Loading Spotify…").accessibilityIdentifier("fri.spotify.loading") }
                if let error = player.error {
                    Text(error).accessibilityIdentifier("fri.spotify.error")
                    Button("Try again") { player.retry() }.accessibilityIdentifier("fri.spotify.retry")
                }
                if let webView = player.webView {
                    FRISpotifyWebView(webView: webView)
                        .id(ObjectIdentifier(webView))
                        .frame(height: 352)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("fri.spotify.web")
                } else { Spacer(minLength: 0) }
                HStack {
                    if let url = player.resourceURL { Link("Open in Spotify", destination: url) }
                    Button("Reload") { player.retry() }.accessibilityIdentifier("fri.spotify.reload")
                    Spacer()
                    Button("Disconnect", role: .destructive, action: onDisconnect).accessibilityIdentifier("fri.spotify.disconnect")
                }
                .friFont(.caption)
            }
            .padding(16)
        }
        .background(FRIColors.sidebar)
        .foregroundStyle(FRIColors.cream)
        .tint(FRIColors.cream)
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 328, minHeight: 408)
        .environment(\.dynamicTypeSize, player.largeText ? .xxxLarge : .large)
        #endif
    }
}

#if os(macOS)
private struct FRISpotifyWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
private struct FRISpotifyWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
