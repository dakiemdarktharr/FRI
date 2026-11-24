import SwiftUI
#if os(macOS)
import AppKit
#endif

public extension View {
    /// Retains native Dynamic Type on iOS and gives FRI's reading preference
    /// an explicit point-size adjustment on macOS, where semantic fonts do not
    /// scale in response to the SwiftUI DynamicTypeSize environment alone.
    func friFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(FRIReadingFont(style: style, weight: weight))
    }
}

private struct FRIReadingFont: ViewModifier {
    let style: Font.TextStyle
    let weight: Font.Weight?
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content.font(resolvedFont)
    }

    private var resolvedFont: Font {
        #if os(macOS)
        let preferred = NSFont.preferredFont(forTextStyle: macStyle)
        let size = preferred.pointSize * macScale
        // Resizing the system descriptor preserves its semantic weight and
        // language-specific font metrics instead of hard-coding a typeface.
        let font = Font(NSFont(descriptor: preferred.fontDescriptor, size: size) ?? preferred)
        #else
        let font = Font.system(style)
        #endif
        return weight.map { font.weight($0) } ?? font
    }

    #if os(macOS)
    private var macScale: CGFloat {
        // Desktop 0.5 uses 1.16 for its reading preference. Larger preview
        // categories also exercise widget fit without changing system settings.
        switch typeSize {
        case .xSmall, .small, .medium, .large: 1
        case .xLarge: 1.05
        case .xxLarge: 1.10
        case .xxxLarge: 1.16
        case .accessibility1: 1.5
        case .accessibility2: 1.75
        case .accessibility3: 2
        case .accessibility4: 2.25
        case .accessibility5: 2.5
        @unknown default: 1
        }
    }

    private var macStyle: NSFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
    #endif
}
