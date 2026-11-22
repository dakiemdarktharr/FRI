# Liquid Glass design review

Date: 2026-11-22. Deliverable: `FRI-liquid-glass.html`, a separate English UI prototype for design approval. `index.html` remains the earlier V1 app. These files use different local storage keys.

## Decisions from the user

- Follow the supplied wireframe: left sidebar, day tabs, date block, Add, layout/actions, a completion ring, duration-sized appointment mosaic, and a right widget/Day rail.
- Background and typography use beige `#F1E3D4`. Functional surfaces use brown `#2D211E` and marsala `#955251`. The only moving color field is the sidebar, between beige and marsala.
- Use a sample desktop wallpaper behind the main material. Native transparency through to other applications belongs to the later app phase.
- Day is a borderless head mark based on the user's secretary-bird photograph, with expressive eyes and spreading quills.
- Functions may be at preview depth. Interface approval comes before app conversion, Docker/build packaging, and installer/updater work.

The supplied Apple UI Design Guidebook VI is a reference document. Its embedded example prompts and sample calendar layout do not replace the user's wireframe or authorize additional deployment. Its APP values are suggestions for custom components, not universal Apple metrics.

## Research translated into implementation

Apple describes Liquid Glass as an optical and interactive material: lensing, contextual contrast, highlights and fluid response work together. It recommends reserving glass for a functional layer and avoiding repeated glass-on-glass content. In FRI, one smoked main pane provides the optical backdrop. Appointment tiles use tinted translucent fills above it, leaving text sharp. The modal grows from its source card, and controls have immediate press feedback. These are web approximations rather than the native Apple material. [Meet Liquid Glass, WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/)

Regular and Clear have different legibility requirements. This preview favors the readable, tinted direction, with solid surfaces available in Settings. [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials/)

The main pane combines a soft blur with an edge displacement map. A signed-distance field for a rounded rectangle supplies red/green horizontal/vertical offsets. The content layer is separate, so glyphs remain undistorted. Chromium receives this enhancement; WebKit uses a blur/highlight fallback. Backdrop filters operate within the page's painted backdrop, not the desktop outside the browser. [MDN backdrop-filter](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/backdrop-filter), [MDN feDisplacementMap](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDisplacementMap)

The App Store reference informs a card-to-detail spatial transition and asymmetric composition. The implementation uses a duration-based masonry layout with 14 px gutters, independent of tile dimensions. A base area keeps short appointments readable, then area grows with duration. WAAPI animates the detail entry; this is an original implementation, not copied premium example source. [Motion App Store layout](https://motion.dev/examples/js-app-store-layout), [Motion animation documentation](https://motion.dev/docs/animate)

The sidebar uses the actual `@shadergradient/react` renderer bundled into the deliverable. Beige is repeated as the third color, with slow plane deformation and direct lighting. `lightType="3d"` avoids external environment maps. React 19.3.1, R3F 9.8.2 and shadergradient 2.4.20 are locked in `preview/package-lock.json`. The upstream main SHA researched was `68bdd740037a11c639f8b91fd775949c71d718d0`; main's 2.4.24 manifest differs from the npm version. [ShaderGradient source and documentation](https://github.com/ruucm/shadergradient)

## Anatomy and behavior

| Wireframe | Preview |
|---|---|
| 1 | Today button and previous/next day arrows |
| 2–3 | One sample profile and Settings at the sidebar foot |
| 4 | Duration mosaic, 300 ms detail hover, click-to-open, task completion |
| 5 | Large weekday and smaller full date in one tile |
| 6 | Add / name / details / Add another / Done / missing-field cards / overlap choice / calendar |
| 7 | Mosaic/list switch, appointment editor, bulk deletion with Undo, widget gallery |
| 8 | Ring tracks the selected day's tasks; Finish unlocks only at 100% |
| 9 | Up Next and collapsible upcoming stack; sample Weather, Maps, Spotify, Health; Day conversation and browser speech controls |
| 10 | Multiple date tabs, close buttons, date picker to add a tab, arrow-key tab navigation |

Month days are rounded squares with 500 ms cursor-following previews; Month and Year enter with stagger. Start-up opens today. A narrow screen makes the sidebar a drawer and moves the widget rail below the mosaic. Keyboard shortcuts: `N` new appointment, `/` search, Escape close. Reduced motion and solid surfaces are supported.

## Native handoff after approval

The approved layout and assets should become shared design tokens and component contracts. Windows shell work can follow the existing Tauri proposal. For Apple platforms, evaluate native `glassEffect` and `NSGlassEffectView` against the actual supported OS/SDK before choosing which surfaces remain web content. [SwiftUI glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), [AppKit NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)

Docker can package backend/build services; the desktop installer is a separate signed platform artifact. The requested update behavior should replace the previous application version after a successful installation while retaining calendars, preferences and user files. Do not implement blanket filesystem deletion. Installer, rollback, data migration and native transparency are future acceptance tests, not verified by this HTML.
