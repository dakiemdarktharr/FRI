import SwiftUI
import FRIDesign
import ImageIO
#if os(macOS)
import AppKit
#endif

struct FRIWindowBackdrop: View {
    let enabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        #if os(macOS)
        ZStack {
            FRIColors.workspace
            if enabled && !reduce && contrast != .increased {
                FRIMacMaterial(enabled: true).opacity(0.25)
            }
        }
        #else
        Rectangle().fill(FRIColors.workspace)
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
    let image: Data?
    let motion: Bool
    @State private var bitmap: CGImage?
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if mode == "solid" {
                    FRIColors.sidebar
                } else {
                    LinearGradient(colors: [FRIColors.sidebar, FRIColors.marsala.opacity(0.65), FRIColors.muted], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                if mode == "image", let bitmap {
                    artwork(Image(decorative: bitmap, scale: 1), size: proxy.size)
                } else if mode != "solid" {
                    TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduced || !motion || scenePhase != .active)) { context in
                        let y = reduced || !motion ? 0.72 : 0.65 + 0.17 * sin(context.date.timeIntervalSinceReferenceDate / 12)
                        RadialGradient(colors: [FRIColors.marsala.opacity(0.4), FRIColors.cream.opacity(0.08), .clear],
                                       center: UnitPoint(x: 0.19, y: y), startRadius: 5, endRadius: 320)
                    }
                }
            }.clipped()
        }.accessibilityHidden(true)
        .task(id: image) {
            bitmap = nil
            guard let image else { return }
            let decoded = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithData(image as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil as CGImage? }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 720
                ] as CFDictionary)
            }.value
            guard !Task.isCancelled else { return }
            bitmap = decoded
        }
    }

    private func artwork(_ image: Image, size: CGSize) -> some View {
        image.resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .overlay(FRIColors.sidebar.opacity(0.55))
    }
}
