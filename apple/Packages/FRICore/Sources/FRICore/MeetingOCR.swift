#if os(macOS)
import CoreGraphics
import Foundation
import Vision

public enum MeetingOCR {
    public enum Region {
        case conversation, zaloComposer
        func pixels(in image: CGImage) -> CGRect {
            let width = CGFloat(image.width), height = CGFloat(image.height)
            switch self {
            case .conversation:
                return CGRect(x: width * 0.25, y: height * 0.18, width: width * 0.74, height: height * 0.68)
            case .zaloComposer:
                // Zalo's editable line is directly above the lower edge, below its attachments toolbar.
                let band = min(height * 0.068, width * 0.039)
                return CGRect(x: width * 0.22, y: height - band, width: width * 0.55, height: band)
            }
        }
    }

    /// Only changed regions go through OCR. A separate signature catches typing
    /// even while the conversation above the composer is completely static.
    public static func signature(_ image: CGImage, region: Region = .conversation) -> Data? {
        let region = region.pixels(in: image)
        guard let crop = image.cropping(to: region),
              let context = CGContext(data: nil, width: 160, height: 96, bitsPerComponent: 8,
                                      bytesPerRow: 160, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let bytes = context.data else { return nil }
        context.interpolationQuality = .low
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 160, height: 96))
        return Data(bytes: bytes, count: 160 * 96)
    }

    private static func textRequest() throws -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let languages = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["vi-VN","en-US"].filter(languages.contains)
        request.usesLanguageCorrection = false
        return request
    }

    public static func draftText(_ image: CGImage) throws -> String {
        guard let crop = image.cropping(to: Region.zaloComposer.pixels(in: image)) else { return "" }
        let request = try textRequest()
        try VNImageRequestHandler(cgImage: crop).perform([request])
        let lines = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        return lines.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    public static func rows(_ image: CGImage) throws -> [[String: String]] {
        let request = try textRequest()
        // Avoid the sidebar, toolbar and unsent composer. Coordinates are relative to this window.
        request.regionOfInterest = CGRect(x: 0.25, y: 0.14, width: 0.74, height: 0.68)
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }.compactMap {
            guard let text = $0.topCandidates(1).first?.string, text.count <= 480,
                  text.range(of: #"^\s*[\d:./\s]+\s*$"#, options: .regularExpression) == nil else { return nil }
            let rect = $0.boundingBox
            let side = rect.minX >= 0.58 && rect.maxX > 0.78 ? "own" : (rect.minX < 0.52 && rect.maxX < 0.80 ? "other" : "unknown")
            return ["text": text, "side": side]
        }
    }
}

#endif
