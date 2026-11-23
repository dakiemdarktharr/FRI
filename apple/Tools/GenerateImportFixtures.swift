import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func line(_ title: String, in context: CGContext, size: CGFloat) {
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1800, height: 400))
    context.textPosition = CGPoint(x: 40, y: 160)
    let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black])
    CTLineDraw(CTLineCreateWithAttributedString(text), context)
}
func bitmap(_ title: String) -> CGImage {
    let context = CGContext(data: nil, width: 1800, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    line(title, in: context, size: 48)
    return context.makeImage()!
}
let image = bitmap("QA image import 2026-11-25 10:30")
let output = CGImageDestinationCreateWithURL(root.appendingPathComponent("import-image.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, image, nil)
precondition(CGImageDestinationFinalize(output))
for scanned in [false, true] {
    var page = CGRect(x: 0, y: 0, width: 900, height: 200)
    let file = root.appendingPathComponent(scanned ? "import-scan.pdf" : "import-text.pdf")
    let context = CGContext(file as CFURL, mediaBox: &page, nil)!
    context.beginPDFPage(nil)
    if scanned {
        context.draw(bitmap("QA scanned import 2026-11-25 11:00"), in: page)
    } else {
        context.scaleBy(x: 0.5, y: 0.5)
        line("QA PDF import 2026-11-25 10:00", in: context, size: 48)
    }
    context.endPDFPage()
    context.closePDF()
}
