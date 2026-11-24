#if os(macOS)
import AppKit
@testable import FRIDesign
import SwiftUI
import Testing

@MainActor
struct WindowBackdropTests {
    @Test func materialRestoresEachWindowOnDisableMoveAndRemoval() {
        let first = window(background: .red)
        let second = window(background: .blue)
        let effect = FRIWindowMaterialView(frame: first.contentView!.bounds)
        effect.enabled = true // SwiftUI can update before the AppKit view is attached.
        first.contentView!.addSubview(effect)
        #expect(!first.isOpaque)
        #expect(first.backgroundColor == .clear)
        #expect(effect.state == .active && !effect.isHidden)
        effect.enabled = false
        #expect(first.isOpaque && first.backgroundColor == .red)
        #expect(effect.state == .inactive && effect.isHidden)
        effect.enabled = true
        second.contentView!.addSubview(effect)
        #expect(first.isOpaque && first.backgroundColor == .red)
        #expect(!second.isOpaque && second.backgroundColor == .clear)
        effect.removeFromSuperview()
        #expect(second.isOpaque && second.backgroundColor == .blue)
        #expect(first.isOpaque && first.backgroundColor == .red)
    }

    @Test func materialPreservesAnOriginallyTransparentWindow() {
        let host = window(background: .green)
        host.isOpaque = false
        let effect = FRIWindowMaterialView(frame: .zero)
        host.contentView!.addSubview(effect)
        effect.enabled = true
        effect.enabled = false
        #expect(!host.isOpaque && host.backgroundColor == .green)
        host.backgroundColor = .yellow // Recapture a new baseline on the next activation.
        effect.enabled = true
        effect.removeFromSuperview()
        #expect(!host.isOpaque && host.backgroundColor == .yellow)
    }

    @Test func swiftUISettingAndRemovalRestoreWindowAppearance() async throws {
        let host = window(background: .purple)
        func content(_ enabled: Bool) -> AnyView {
            AnyView(FRIWindowBackdrop(enabled: enabled))
        }
        let view = NSHostingView(rootView: content(true))
        host.contentView = view
        func settle() async throws {
            view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            view.layoutSubtreeIfNeeded()
        }
        try await settle()
        #expect(!host.isOpaque && host.backgroundColor == .clear)
        for _ in 0..<3 {
            view.rootView = content(false)
            try await settle()
            #expect(host.isOpaque && host.backgroundColor == .purple)
            view.rootView = content(true)
            try await settle()
            #expect(!host.isOpaque && host.backgroundColor == .clear)
        }
        view.rootView = AnyView(Color.clear)
        try await settle()
        #expect(host.isOpaque && host.backgroundColor == .purple)
    }

    private func window(background: NSColor) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = background
        return window // Never ordered on screen; tests use actual AppKit attachment/layout.
    }
}
#endif
