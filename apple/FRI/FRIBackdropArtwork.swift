import SwiftUI
import FRIDesign
import ImageIO
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
                FRIColors.cloud
                if mode == "image", let bitmap {
                    artwork(Image(decorative: bitmap, scale: 1), size: proxy.size)
                } else if mode != "solid" {
                    FRIGradientView(motion: motion && !reduced, active: scenePhase == .active)
                        .opacity(0.12)
                        .allowsHitTesting(false)
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
            .overlay(FRIColors.cloud.opacity(0.55))
    }
}
