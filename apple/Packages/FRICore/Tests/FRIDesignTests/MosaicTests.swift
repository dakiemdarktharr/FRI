#if os(macOS)
import AppKit
import FRIDesign
import SwiftUI
import Testing

@MainActor
struct MosaicTests {
    @Test func desktopDurationsAndColumnRatios() {
        let frames = rendered(width: 928, durations: [30, 60, 120, 15, 240])
        // Independently calculated from shipping preview/app.js renderMosaic
        // and style.css's 280-point minimum, including column-one's short tile.
        let expected: [CGRect] = [
            CGRect(x: 0, y: 0, width: 282, height: 301),
            CGRect(x: 296, y: 0, width: 336, height: 282),
            CGRect(x: 646, y: 0, width: 282, height: 406),
            CGRect(x: 296, y: 296, width: 336, height: 280),
            CGRect(x: 0, y: 315, width: 282, height: 547)
        ]
        #expect(frames.count == expected.count)
        for (actual, reference) in zip(frames, expected) {
            #expect(abs(actual.minX - reference.minX) < 0.1)
            #expect(abs(actual.minY - reference.minY) < 0.1)
            #expect(abs(actual.width - reference.width) < 0.1)
            #expect(abs(actual.height - reference.height) < 0.1)
        }
    }

    @Test func narrowListAndReadingLayoutsPreserveContent() {
        let narrow = rendered(width: 320, durations: [30, 120])
        #expect(narrow[1].minY == narrow[0].maxY + 14)
        let phone = rendered(width: 370, durations: [30, 120])
        #expect(phone[0].width == 178 && phone[1].minX == 192)
        #expect(phone[1].height > phone[0].height)
        for reading in [false, true] {
            let frames = rendered(width: 720, durations: [30, 120], reading: reading, list: !reading, contentHeight: 420)
            #expect(frames[0].width == 720)
            #expect(frames[0].height >= 420)
            #expect(frames[1].minY == frames[0].maxY + 14)
        }
    }

    private func rendered(width: CGFloat, durations: [Int], reading: Bool = false,
                          list: Bool = false, contentHeight: CGFloat = 10) -> [CGRect] {
        var probes: [NSView] = []
        let content = FRIMosaic(durations: durations, largeText: reading, list: list) {
            ForEach(durations.indices, id: \.self) { index in
                Probe { view in probes.append(view) }
                    .frame(minHeight: contentHeight, maxHeight: .infinity)
            }
        }.frame(width: width)
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        return probes.map { $0.convert($0.bounds, to: host) }
    }

    private struct Probe: NSViewRepresentable {
        let created: (NSView) -> Void
        func makeNSView(context: Context) -> NSView {
            let view = NSView(); created(view); return view
        }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }
}
#endif
