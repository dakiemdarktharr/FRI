#if os(macOS)
import AppKit
import FRIDesign
import Testing

struct DesktopWidgetPlacementTests {
    private let primary = CGRect(x: 0, y: 30, width: 1440, height: 840)
    private let left = CGRect(x: -1920, y: 30, width: 1920, height: 1050)

    @Test func preservesPlacementOnAnAttachedSecondaryDisplay() {
        let original = CGRect(x: -1500, y: 200, width: 360, height: 390)
        #expect(DesktopWidgetPlacement.fitting(original, visibleFrames: [primary, left]) == original)
    }

    @Test func removedDisplayReturnsWidgetToVisiblePrimaryArea() {
        let original = CGRect(x: -1500, y: 200, width: 360, height: 390)
        let restored = DesktopWidgetPlacement.fitting(original, visibleFrames: [primary])
        #expect(primary.contains(restored))
        #expect(restored.size == original.size)
        #expect(restored.maxY == original.maxY)
        #expect(restored.minX == primary.minX)
    }

    @Test func spanningWidgetStaysOnDisplayContainingMostOfIt() {
        let original = CGRect(x: -300, y: 200, width: 360, height: 210)
        let restored = DesktopWidgetPlacement.fitting(original, visibleFrames: [primary, left])
        #expect(left.contains(restored))
        #expect(restored.maxX == left.maxX)
        #expect(restored.size == original.size)
    }

    @Test func smallerVisibleAreaFitsEvenWhenBelowUsualMinimum() {
        let visible = CGRect(x: 80, y: 60, width: 200, height: 120)
        let original = CGRect(x: 100, y: 100, width: 900, height: 1000)
        #expect(DesktopWidgetPlacement.fitting(original, visibleFrames: [visible]) == visible)
    }

    @Test func dockAndMenuBarRemainOutsideWidget() {
        let original = CGRect(x: 1300, y: 0, width: 360, height: 390)
        let restored = DesktopWidgetPlacement.fitting(original, visibleFrames: [primary])
        #expect(primary.contains(restored))
        #expect(restored.minY == primary.minY)
        #expect(restored.maxX == primary.maxX)
        #expect(DesktopWidgetPlacement.fitting(restored, visibleFrames: [primary]) == restored)
    }

    @Test func missingScreensLeaveSavedPlacementUntouched() {
        let original = CGRect(x: -1500, y: 200, width: 360, height: 390)
        #expect(DesktopWidgetPlacement.fitting(original, visibleFrames: []) == original)
        #expect(DesktopWidgetPlacement.fitting(original, visibleFrames: [.zero, .null]) == original)
    }

    @MainActor @Test func multipleAppKitPanelsRetainIndependentFramesWhenRecovered() {
        let originals = [CGRect(x: -1500, y: 200, width: 360, height: 390),
                         CGRect(x: 500, y: 400, width: 240, height: 180)]
        let panels = originals.map { frame in
            NSPanel(contentRect: frame, styleMask: [.borderless, .resizable, .nonactivatingPanel],
                    backing: .buffered, defer: false)
        }
        defer { panels.forEach { $0.close() } }
        for panel in panels {
            panel.isReleasedWhenClosed = false
            panel.setFrame(DesktopWidgetPlacement.fitting(panel.frame, visibleFrames: [primary]), display: false)
            #expect(primary.contains(panel.frame))
        }
        #expect(panels[0].frame.size == originals[0].size)
        #expect(panels[1].frame == originals[1])
        #expect(panels[0].frame != panels[1].frame)
    }
}
#endif
