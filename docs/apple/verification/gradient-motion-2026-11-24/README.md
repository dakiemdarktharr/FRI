# Sidebar motion restart — 2026-11-24

The desktop recreates its ShaderGradient canvas when the motion setting changes. ShaderGradient 2.4.20 also starts its own Three.js clock when animation is enabled. Native previously kept one start instant for the renderer's entire lifetime, so enabling motion after a long pause showed a later animation phase.

The native renderer now resets its monotonic start instant only on the off-to-on transition. Unrelated SwiftUI updates do not restart animation. The paused frame remains at time 6; shader geometry, palette, camera and the 15 fps budget are unchanged.

## Observed evidence

- Shipping desktop HTML, three real motion cycles: paused `uTime` is 6; re-enabled clocks at approximately 250 ms are 0.1931, 0.1774 and 0.1898; after a further two seconds they advance past 2.17. `desktop-motion-cycles.json` records the actual uniforms without overriding them.
- iPad mini (A20 Pro), iPadOS 27.2: the same UI test checks stationary paused pixels, changing animated pixels, then turns motion off for 20 seconds and re-enables it through Settings. It compares the text-free left sidebar edge after the same enable interaction. Threshold fixed before the first run: mean absolute difference below 2 across decoded PNG pixel-buffer bytes, including alpha.
- Before fix: **FAIL**, difference 16.97366794064748, `test_sim_2026-11-23T23-43-31-776Z_pid22065_1f7890b4.xcresult`.
- After fix: **PASS**, difference 0.29197111061151076, `test_sim_2026-11-23T23-44-52-863Z_pid22065_0586c9d9.xcresult`; one pass, zero failures/skips, 64.733 seconds. Leaves motion disabled.
- The `before-*` and `after-*` PNG pairs are original test crop attachments. Their narrow width is intentional: no text, clock or foreground control overlaps the sampled region. `comparison.json` records the metric; this is a temporal phase comparison, not whole-screen pixel parity.
- macOS Debug build passed with no warning/error diagnostics: `/tmp/fri-gradient-restart-mac.log`. A fresh Computer Use attempt still returned `cgWindowNotFound` for the QA Mac app, so Mac onscreen behavior is not claimed.

Run the reference audit with Playwright available to Node:

```sh
node apple/Tools/AuditGradientMotion.mjs FRI-liquid-glass.html /tmp/fri-gradient-motion-reference.json
```

`FRI_PLAYWRIGHT_MODULE` can select an existing Playwright module and `FRI_CHROMIUM` an existing Chromium executable. Native test: `FRIiOSUITests/FRIWorkflowTests/testSidebarGradientMotionAndPause`, on a wide iPad Simulator.

The reference's paused camera remains unsettled and varies across mounts: the captured view-space translation Z ranges from approximately -5.0057 to -5.0464. Native still uses the configured camera pose. This change closes the animation-clock mismatch, not the separate paused-camera or complete visual-equivalence gates.
