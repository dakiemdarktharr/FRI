# Glass, responsiveness and performance

Preserve Cloud/Ink/Teal light and dark palette, FRI mark, rounded corners, bundled Inter typography (system fonts for OS-owned controls), compact day feed/equal gaps and day-first navigation. Keep local sidebar images, motion, glass and large-text settings. Narrow layouts collapse sidebar and use readable columns; every hover action has touch/keyboard access.

On supported Mac, verify actual behind-window backdrop. Browser CSS only refracts page content. iOS does not expose arbitrary other-app windows behind your app; do not promise cross-app transparency there.

Use SwiftUI glassEffect, rounded rectangles, system glass buttons and GlassEffectContainer on OS26+, availability-guarded with material/solid fallback. Do not stack glass at the expense of readability. AppKit NSGlassEffectView (26+) exposes contentView, cornerRadius/style/tint; configure the NSWindow and verify composition. Older macOS uses NSVisualEffectView behindWindow. Reduced transparency/high contrast must be solid and readable. [SwiftUI](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [AppKit](https://developer.apple.com/documentation/appkit/nsglasseffectview).

## Library research

- [hicccc77/electron-liquid-glass](https://github.com/hicccc77/electron-liquid-glass): source reviewed at 0684fe7fd74855e4b13bd3e8d7b6db40f91e132a; npm @hicccc77/electron-liquid-glass0.3.0, MIT. Windows x64 desktop capture/D3D refraction/DirectComposition, not Apple's compositor or a Mac backend. FRI adapter: desktop/glass.cjs.
- [Meridius-Labs/electron-liquid-glass](https://github.com/Meridius-Labs/electron-liquid-glass): separate binding for Apple's native macOS26+ glass. Candidate if retaining Electron; review/pin current source/license/ABI on Mac. Not integrated/built here.
- [rdev/liquid-glass-react](https://github.com/rdev/liquid-glass-react): web-layer refraction, not external desktop transparency.

Windows pixels remain in native GPU memory; the glass panel excludes itself from captures to avoid recursion. Captures can differ from visible output. Never expose pixels through JS/IPC, persist/upload them or ship diagnostic capture modes. Apple material should not need Screen Recording permission just for UI.

Pause hidden/offscreen motion, reuse contexts/textures, coalesce writes and update changed IDs. No WidgetKit frame loops. Move OCR/parsing off UI actors. Measure device/OS/workload with Instruments Time Profiler/Allocations/Energy; upstream benchmark claims are not FRI evidence. Record frame sequences for drag/resize, views, completion/intake and controlled moving backdrop; test reduced modes, minimize/restore, full screen, Spaces, display scales and GPU loss. Chromium screenshots alone cannot verify compositor optics.
