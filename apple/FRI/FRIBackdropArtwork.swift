import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct FRIWindowBackdrop: View {
    let enabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        #if os(macOS)
        FRIMacMaterial(enabled: enabled && !reduce && contrast != .increased)
        #else
        Rectangle().fill(.background)
        #endif
    }
}

#if os(macOS)
private struct FRIMacMaterial: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let effect = NSVisualEffectView()
        effect.blendingMode = .behindWindow
        effect.material = .underWindowBackground
        return effect
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = enabled ? .active : .inactive
        view.isHidden = !enabled
        DispatchQueue.main.async { [weak view] in
            view?.window?.isOpaque = !enabled
            view?.window?.backgroundColor = enabled ? .clear : .windowBackgroundColor
        }
    }
}
#endif

struct FRIBackdropArtwork: View {
    let mode: String
    let image: String?
    let motion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(.background)
                if mode == "image", let image, let data = Data(base64Encoded: image) {
                    #if os(macOS)
                    if let bitmap = NSImage(data: data) { artwork(Image(nsImage: bitmap), size: proxy.size) }
                    #else
                    if let bitmap = UIImage(data: data) { artwork(Image(uiImage: bitmap), size: proxy.size) }
                    #endif
                } else if mode != "solid" {
                    TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduced || !motion || scenePhase != .active)) { context in
                        let y = reduced || !motion ? 0.72 : 0.65 + 0.17 * sin(context.date.timeIntervalSinceReferenceDate / 12)
                        RadialGradient(colors: [.primary.opacity(0.25), .primary.opacity(0.08), .clear],
                                       center: UnitPoint(x: 0.19, y: y), startRadius: 5, endRadius: 320)
                    }
                    artwork(Image("DayBackdrop"), size: proxy.size)
                }
            }.clipped()
        }.accessibilityHidden(true)
    }

    private func artwork(_ image: Image, size: CGSize) -> some View {
        image.resizable().scaledToFill().saturation(0).opacity(0.16)
            .frame(width: size.width, height: size.height, alignment: .bottom).clipped()
    }
}
