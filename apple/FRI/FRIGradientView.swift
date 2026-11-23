import MetalKit
import SwiftUI

#if os(macOS)
private typealias FRIPlatformViewRepresentable = NSViewRepresentable
#else
private typealias FRIPlatformViewRepresentable = UIViewRepresentable
#endif

/// Native rendering of the shipping desktop's ShaderGradient plane.
struct FRIGradientView: FRIPlatformViewRepresentable {
    let motion: Bool
    let active: Bool

    func makeCoordinator() -> Renderer { Renderer() }

    #if os(macOS)
    func makeNSView(context: Context) -> MTKView { makeView(context) }
    func updateNSView(_ view: MTKView, context: Context) { update(view, context) }
    static func dismantleNSView(_ view: MTKView, coordinator: Renderer) { stop(view) }
    #else
    func makeUIView(context: Context) -> MTKView { makeView(context) }
    func updateUIView(_ view: MTKView, context: Context) { update(view, context) }
    static func dismantleUIView(_ view: MTKView, coordinator: Renderer) { stop(view) }
    #endif

    private func makeView(_ context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: Renderer.resources?.device)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        #if os(macOS)
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        #else
        (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        #endif
        view.clearColor = MTLClearColor(red: 48.0 / 255, green: 41.0 / 255, blue: 41.0 / 255, alpha: 1)
        view.preferredFramesPerSecond = 15
        view.delegate = context.coordinator
        #if os(iOS)
        view.isUserInteractionEnabled = false
        #endif
        update(view, context)
        return view
    }

    private func update(_ view: MTKView, _ context: Context) {
        context.coordinator.motion = motion
        view.isPaused = !motion || !active || Renderer.resources == nil
        view.enableSetNeedsDisplay = view.isPaused
        #if os(macOS)
        view.needsDisplay = true
        #else
        view.setNeedsDisplay()
        #endif
    }

    private static func stop(_ view: MTKView) {
        view.isPaused = true
        view.delegate = nil
        view.releaseDrawables()
    }

    @MainActor
    final class Renderer: NSObject, MTKViewDelegate {
        static let resources = Resources()
        private var started = ContinuousClock.now
        var motion = true {
            didSet {
                // The desktop remounts ShaderGradient when motion is enabled, restarting its clock.
                if motion && !oldValue { started = .now }
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let resources = Self.resources, view.drawableSize.width > 0, view.drawableSize.height > 0,
                  let buffer = resources.queue.makeCommandBuffer(),
                  let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
            let elapsed = started.duration(to: .now).components
            let time = motion ? Float(elapsed.seconds) + Float(elapsed.attoseconds) / 1e18 : 6
            var parameters = SIMD2<Float>(Float(view.drawableSize.width / view.drawableSize.height), time)
            encoder.setRenderPipelineState(resources.pipeline)
            encoder.setDepthStencilState(resources.depth)
            encoder.setVertexBytes(&parameters, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 192 * 6)
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }
    }

    @MainActor
    final class Resources {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let pipeline: MTLRenderPipelineState
        let depth: MTLDepthStencilState

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
                  let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "friGradientVertex"),
                  let fragment = library.makeFunction(name: "friGradientFragment") else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .lessEqual
            depthDescriptor.isDepthWriteEnabled = true
            guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else { return nil }
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            self.device = device
            self.queue = queue
            self.pipeline = pipeline
            self.depth = depth
        }
    }
}
