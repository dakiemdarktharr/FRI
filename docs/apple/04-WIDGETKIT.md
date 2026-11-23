# Native widgets

Use WidgetKit, SwiftUI and AppIntents. Start with [extension creation](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension) and [configuration](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget).

Define WidgetConfigurationIntent with selected date/calendar policy and optional services, default Today. AppIntentTimelineProvider implements placeholder, snapshot and timeline. Snapshot works without data/network. Use containerBackground(for: .widget), system margins, systemSmall/Medium/Large and extraLarge only where exposed. Never interpret Windows pixel bounds as WidgetFamily.

Priority: current task + Done; weekday; date; progress; connected services/manual steps; later tasks. Fit family and Dynamic Type. Small retains title/time/reachable Done; medium splits task/date; large adds services. Empty: “A fresh day.” All completed: “Your day is clear.” Provider failure never hides tasks. Mark private fields privacySensitive, supply locked placeholders, readable contrast and descriptive progress accessibility labels. Test full-color, accented/vibrant and clear/tinted appearance. [Rendering contexts](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances), [Liquid Glass](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass).

## Durable Done

CompleteTaskIntent receives task ID and operation identity. perform() reads the protected shared store, validates existence, atomically sets done=true and returns after persistence. Never toggle or overwrite from an old snapshot. Recompute next task/progress. WidgetKit reloads after interactive actions; app writes request WidgetCenter.shared.reloadTimelines(ofKind:). Handle locked keys, deleted task and failed writes. Opening Spotify/maps/editing uses Link/widgetURL, not a fake completion action. [Interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

## Timelines and network

Generate bounded entries for now, task boundaries and local midnight using Calendar/time zone, not fixed 86,400-second days. Include weather fetchedAt/stale state. Reload after the last useful entry; no per-second timer. The OS can delay refresh. Prefer app-fetched cached information; extension networking uses bounded URLSession requests, cancellation and cached fallback, completing background handlers. No WebView/music stream/map tile polling inside widgets. [Budgets](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [networking](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension).

## Placement and lifecycle

Guide iPhone/iPad users through Home Screen Edit/Add Widget → FRI → size → Add; Mac through Edit Widgets → FRI → desktop. Verify exact OS menu wording. The app's Create action opens guidance/size preview, never falsely claims installation. System controls move/resize/remove; no private APIs or Finder icon automation. Removal does not delete tasks. Test add, duplicates, double Done, app terminated, reboot/lock, midnight/DST, family changes, Mac Spaces/displays and remove/re-add on real devices.
