#if os(macOS)
import Foundation

/// Keeps a desktop widget reachable after restoring or changing display configuration.
public enum DesktopWidgetPlacement {
    public static func fitting(_ frame: CGRect, visibleFrames: [CGRect]) -> CGRect {
        let screens = visibleFrames.filter { !$0.isEmpty && !$0.isInfinite && !$0.isNull }
        guard var screen = screens.first else { return frame }
        var largestOverlap: CGFloat = 0
        for candidate in screens {
            let overlap = candidate.intersection(frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > largestOverlap {
                screen = candidate
                largestOverlap = area
            }
        }
        // The first screen is the primary display when a removed display has no overlap.
        let width = min(max(frame.width, 220), screen.width)
        let height = min(max(frame.height, 140), screen.height)
        return CGRect(
            x: min(max(frame.minX, screen.minX), screen.maxX - width),
            y: min(max(frame.maxY - height, screen.minY), screen.maxY - height),
            width: width, height: height
        )
    }
}
#endif
