import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct FRIWindowBackdrop: View {
    let enabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @Environment(\.colorSchemeContrast) private var contrast

    public init(enabled: Bool) { self.enabled = enabled }

    public var body: some View {
        #if os(macOS)
        ZStack {
            if enabled && !reduce && contrast != .increased {
                FRIMacMaterial(enabled: true)
                FRIColors.cloud.opacity(0.76)
            } else { FRIColors.cloud }
        }
        #else
        Rectangle().fill(FRIColors.cloud)
        #endif
    }
}

#if os(macOS)
private struct FRIMacMaterial: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> FRIWindowMaterialView {
        FRIWindowMaterialView(frame: .zero)
    }

    func updateNSView(_ view: FRIWindowMaterialView, context: Context) {
        view.enabled = enabled
    }

    static func dismantleNSView(_ view: FRIWindowMaterialView, coordinator: ()) {
        view.enabled = false
    }
}

/// Owns only the window properties temporarily changed by this material view.
/// Window attachment is synchronous, so a queued update cannot outlive removal.
final class FRIWindowMaterialView: NSVisualEffectView {
    var enabled = false { didSet { applyMaterial() } }
    private weak var modifiedWindow: NSWindow?
    private var originalAppearance: (opaque: Bool, background: NSColor)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        blendingMode = .behindWindow
        material = .underWindowBackground
        state = .inactive
        isHidden = true
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        restoreWindow()
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyMaterial()
    }

    private func applyMaterial() {
        state = enabled ? .active : .inactive
        isHidden = !enabled
        guard enabled, let window else { restoreWindow(); return }
        if modifiedWindow !== window {
            restoreWindow()
            modifiedWindow = window
            originalAppearance = (window.isOpaque, window.backgroundColor)
        }
        window.isOpaque = false
        window.backgroundColor = .clear
    }

    private func restoreWindow() {
        if let window = modifiedWindow, let originalAppearance {
            window.isOpaque = originalAppearance.opaque
            window.backgroundColor = originalAppearance.background
        }
        modifiedWindow = nil
        originalAppearance = nil
    }
}
#endif
