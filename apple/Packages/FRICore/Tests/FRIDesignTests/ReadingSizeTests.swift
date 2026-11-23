#if os(macOS)
import AppKit
import FRIDesign
import SwiftUI
import Testing

@MainActor
struct ReadingSizeTests {
    @Test func readingPreferenceEnlargesRenderedMacText() {
        for style in [Font.TextStyle.body, .headline, .caption, .title2] {
            let normal = measured(style: style, size: .large)
            let reading = measured(style: style, size: .xxxLarge)
            let accessibility = measured(style: style, size: .accessibility1)
            #expect(normal.height > 0)
            #expect(reading.height > normal.height)
            #expect(reading.width > normal.width * 1.1)
            #expect(accessibility.height > reading.height)
        }
    }

    private func measured(style: Font.TextStyle, size: DynamicTypeSize) -> CGSize {
        // Exercise SwiftUI's actual AppKit layout, not a duplicate scale formula.
        let view = NSHostingView(rootView: Text("Lịch hẹn buổi chiều — Wednesday")
            .friFont(style)
            .environment(\.dynamicTypeSize, size))
        return view.fittingSize
    }
}
#endif
