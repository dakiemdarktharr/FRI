// Offscreen GPU probe for the actual compiled app shader; does not open host windows.
// swift RenderGradientProbe.swift <default.metallib> <output.png> [width height time]
import AppKit
import Metal

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fatalError("Expected metallib and output PNG paths") }
let width = arguments.count > 3 ? Int(arguments[3])! : 258
let height = arguments.count > 4 ? Int(arguments[4])! : 698
let time = arguments.count > 5 ? Float(arguments[5])! : 6
let device = MTLCreateSystemDefaultDevice()!
let sourceURL = URL(fileURLWithPath: arguments[1])
let library = try sourceURL.pathExtension == "metal"
    ? device.makeLibrary(source: String(contentsOf: sourceURL, encoding: .utf8), options: nil)
    : device.makeLibrary(URL: sourceURL)
let pipeline = MTLRenderPipelineDescriptor()
pipeline.vertexFunction = library.makeFunction(name: "friGradientVertex")
pipeline.fragmentFunction = library.makeFunction(name: "friGradientFragment")
pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
pipeline.depthAttachmentPixelFormat = .depth32Float
let state = try device.makeRenderPipelineState(descriptor: pipeline)
let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
descriptor.storageMode = .shared
descriptor.usage = [.renderTarget]
let texture = device.makeTexture(descriptor: descriptor)!
let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
depthDescriptor.storageMode = .private
depthDescriptor.usage = [.renderTarget]
let depthTexture = device.makeTexture(descriptor: depthDescriptor)!
let depthStateDescriptor = MTLDepthStencilDescriptor()
depthStateDescriptor.depthCompareFunction = .lessEqual
depthStateDescriptor.isDepthWriteEnabled = true
let depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
let pass = MTLRenderPassDescriptor()
pass.colorAttachments[0].texture = texture
pass.colorAttachments[0].loadAction = .clear
pass.colorAttachments[0].storeAction = .store
pass.colorAttachments[0].clearColor = MTLClearColor(red: 48.0 / 255, green: 41.0 / 255, blue: 41.0 / 255, alpha: 1)
pass.depthAttachment.texture = depthTexture
pass.depthAttachment.loadAction = .clear
pass.depthAttachment.storeAction = .dontCare
pass.depthAttachment.clearDepth = 1
let buffer = device.makeCommandQueue()!.makeCommandBuffer()!
let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)!
var parameters = SIMD2<Float>(Float(width) / Float(height), time)
encoder.setRenderPipelineState(state)
encoder.setDepthStencilState(depthState)
encoder.setVertexBytes(&parameters, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 192 * 6)
encoder.endEncoding()
buffer.commit()
buffer.waitUntilCompleted()
if let error = buffer.error { throw error }
var pixels = [UInt8](repeating: 0, count: width * height * 4)
texture.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
let provider = CGDataProvider(data: Data(pixels) as CFData)!
let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: bitmapInfo, provider: provider,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[2]))
print("Rendered \(width)x\(height), time \(time), GPU \(device.name)")
