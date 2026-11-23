import SwiftUI

public struct FRIMosaic: Layout {
    public let durations: [Int]
    public let largeText: Bool
    public let list: Bool
    private let gutter: CGFloat = 14

    public init(durations: [Int], largeText: Bool = false, list: Bool = false) {
        self.durations = durations
        self.largeText = largeText
        self.list = list
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 420
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, rect) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: rect.width, height: rect.height))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        guard !subviews.isEmpty else { return [] }
        let columns = min(subviews.count, (largeText || list) ? 1 : (width > 680 ? 3 : (width >= 390 ? 2 : 1)))
        let ratios: [CGFloat] = columns == 3 ? [0.94, 1.12, 0.94] : Array(repeating: 1, count: columns)
        let unit = max(0, width - CGFloat(columns - 1) * gutter) / CGFloat(columns)
        var heights = Array(repeating: CGFloat.zero, count: columns)
        return subviews.indices.map { index in
            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            let columnWidth = unit * ratios[column]
            let duration = durations.indices.contains(index) ? CGFloat(durations[index]) : 0
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let baseline = list ? 120 : (145 + min(240, duration * 0.8)) / ratios[column]
            let height = max(measured, baseline)
            let x = ratios.prefix(column).reduce(0, +) * unit + CGFloat(column) * gutter
            let frame = CGRect(x: x, y: heights[column], width: columnWidth, height: height)
            heights[column] += height + gutter
            return frame
        }
    }
}

public struct FRISurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    public let glass: Bool
    public let radius: CGFloat
    public let fill: Color
    public let text: Color

    public init(glass: Bool, radius: CGFloat = 22, fill: Color = FRIColors.cream, text: Color = FRIColors.ink) {
        self.glass = glass
        self.radius = radius
        self.fill = fill
        self.text = text
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .foregroundStyle(text)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(contrast == .increased ? FRIColors.muted : FRIColors.line))
            .shadow(color: .black.opacity(glass && !reduceTransparency ? 0.07 : 0), radius: 10, y: 3)
    }
}
