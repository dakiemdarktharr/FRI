#if os(macOS)
import CoreGraphics
import CoreText
import Foundation
import FRICore
import ImageIO
import Testing

struct MeetingRecognitionTests {
    func window(_ fixture: String) throws -> CGImage {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "png", subdirectory: "MeetingFixtures"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let crop = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try #require(CGContext(data: nil, width: 1200, height: 720, bitsPerComponent: 8, bytesPerRow: 4800,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1200, height: 720))
        context.draw(crop, in: CGRect(x: 300, y: 101, width: 888, height: 490))
        return try #require(context.makeImage())
    }

    @Test func invitationInUnsentComposer() throws {
        let ctx = try #require(CGContext(data: nil, width: 1200, height: 720, bitsPerComponent: 8, bytesPerRow: 4800,
                                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 720))
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 22, nil)
        ]
        func write(_ value: String, y: CGFloat) {
            ctx.textPosition = CGPoint(x: 380, y: y)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: attrs)), ctx)
        }
        write("Mai 19h họp nhé?", y: 290)
        let before = try #require(ctx.makeImage())
        write("ê xíu 9h trạm k", y: 16)
        let after = try #require(ctx.makeImage())
        #expect(MeetingOCR.signature(before) == MeetingOCR.signature(after))
        #expect(MeetingOCR.signature(before, region: .zaloComposer) != MeetingOCR.signature(after, region: .zaloComposer))
        let detector = try MeetingRecognition()
        #expect(try detector.draft(MeetingOCR.draftText(before)) == nil)
        let text = try MeetingOCR.draftText(after)
        let suggestion = detector.draft(text)
        #expect(suggestion?["timeHint"] == "9h", "Synthetic OCR: \(text)")
        #expect(suggestion?["location"] == "trạm")
        #expect(suggestion?["date"] == nil)
        #expect(suggestion?["time"] == nil)
    }

    @Test func localVisionToCalendarProposal() throws {
        let first = try window("proposal")
        let second = try window("accepted")
        let detector = try MeetingRecognition()
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 10)))
        #expect(MeetingOCR.signature(first) != MeetingOCR.signature(second))
        let start = Date.now
        let proposal = try MeetingOCR.rows(first)
        #expect(detector.observe(proposal, at: now) == nil)
        let warm = Date.now
        let rows = try MeetingOCR.rows(second)
        let item = detector.observe(rows, at: now)
        print("Meeting fixture: first OCR \(Int(warm.timeIntervalSince(start) * 1000)) ms, changed frame to proposal \(Int(Date.now.timeIntervalSince(warm) * 1000)) ms")
        #expect(proposal.contains { $0["side"] == "other" })
        #expect(rows.contains { $0["side"] == "own" })
        #expect(item?["title"] == "Họp")
        #expect(item?["date"] == "2026-11-27")
        #expect(item?["time"] == "19:00")
        #expect(detector.observe(rows, at: now) == nil)
        detector.reset()
        #expect(detector.observe(rows, at: now) == nil)
    }
}
#endif
