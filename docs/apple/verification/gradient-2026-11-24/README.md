# Native sidebar gradient evidence

The `desktop-*`/`native-*` pairs compare only the background at equal dimensions and noise times, after the desktop camera reaches its configured pose. `reference.json` contains the captured WebGL uniforms; `comparison.json` contains absolute RGB error across every pixel. Six pairs match within one 8-bit RGB level (mean error below 0.464). The native images were produced by the Mac app's compiled `default.metallib` on Apple M5, using the same depth-test configuration as the app.

`ipad-sidebar-paused.png` is the final native iPad Simulator UI capture. The XCTest workflow verified the background stays unchanged with Gentle motion off and changes after enabling it. All calendar content in this capture is synthetic.

`desktop-paused-unsettled.png` and `desktop-paused-uniforms.json` preserve a separate observation: disabling motion in the shipping desktop pauses its camera before the initial transition finishes. Native immediately uses the configured pose. Do not interpret the controlled-frame comparison as proof that these paused-start states are identical. Whole-window visual parity and macOS onscreen/accessibility checks remain incomplete.

## Reproduce

From the repository root, with Playwright available to Node (or `FRI_PLAYWRIGHT_MODULE` pointing to its `index.mjs`):

```sh
node apple/Tools/CaptureGradientReference.mjs FRI-liquid-glass.html /tmp/fri-gradient-reference-captures
# Set FRI_CHROMIUM only if selecting an existing Chromium executable.
```

Build the Mac app with Xcode, then render each frame using the actual compiled shader:

```sh
swift apple/Tools/RenderGradientProbe.swift /path/to/FRIMac.app/Contents/Resources/default.metallib /tmp/native.png 258 698 6
```

Repeat with the six width/height/time entries in `reference.json`. Compare RGB channels (not PNG file bytes); no resizing, alignment, blur or color correction was applied. The reference capture hides controls and removes corner clipping, while preserving the renderer, palette, tint and camera transition. It freezes the noise uniform only; it does not replace the shader with a mock.

The probe also accepts a `.metal` source path for shader development, but the recorded final comparison used the compiled app library. The new source and license resources are included through XcodeGen's existing `FRI` source directory. See `PRODUCTION-READINESS.md` for exact test bundles, build diagnostics and remaining limitations.
