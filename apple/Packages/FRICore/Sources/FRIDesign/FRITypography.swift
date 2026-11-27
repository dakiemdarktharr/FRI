import CoreText
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
        let face = weight == .bold || weight == .heavy || weight == .black ? "Bold"
            : (weight == .semibold || weight == .medium || style == .headline ? "SemiBold" : "Regular")
        let name = "BeVietnamPro-" + face
        #if os(macOS)
        let preferred = NSFont.preferredFont(forTextStyle: macStyle)
        let size = preferred.pointSize * macScale
        if FRITypeface.names.contains(name) { return .custom(name, fixedSize: size) }
        return .system(size: size, weight: weight ?? .regular)
        #else
        if FRITypeface.names.contains(name) {
            let size: CGFloat = switch style {
            case .largeTitle: 34
            case .title: 28
            case .title2: 22
            case .title3: 20
            case .callout: 16
            case .subheadline: 15
            case .footnote: 13
            case .caption: 12
            case .caption2: 11
            default: 17
            }
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(style, weight: weight)
        #endif
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

private enum FRITypeface {
    // Swift initializes this once in each process, including the widget extension.
    static let names: Set<String> = Set(["Regular", "SemiBold", "Bold"].compactMap { face in
        let name = "BeVietnamPro-" + face
        guard let url = Bundle.module.url(forResource: name, withExtension: "ttf"),
              CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else { return nil }
        return name
    })
}
