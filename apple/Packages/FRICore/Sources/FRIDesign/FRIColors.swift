import SwiftUI

/// Semantic colors shared by the calendar and its widgets (desktop preview/brand.css).
public enum FRIColors {
    public static let cloud = pair(0xF4F7FA, 0x14181F)
    public static let ink = pair(0x172B3A, 0xF2F4F8)
    public static let accent = pair(0x087F8C, 0x75D8CC)
    public static let onAccent = pair(0xFFFFFF, 0x14181F)
    public static let surface = pair(0xFFFFFF, 0x222833)
    public static let control = pair(0xEAF0F4, 0x2C3441)
    public static let muted = pair(0x586D7C, 0xB3BECE)
    public static let line = pair(0xDBE4EB, 0x465368)
    public static let tint = pair(0xE0F2F2, 0x203D3B)

    public static let controlEdge = pair(0x7B8B98, 0x7D8BA1)

    private static func pair(_ light: Int, _ dark: Int) -> Color {
        func components(_ hex: Int) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255)
        }
        let day = components(light), night = components(dark)
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? night : day
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? night : day
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #endif
    }
}
