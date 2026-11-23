# Website revision 2 verification

Run: `node website/build.mjs`, then `node website/verify-v2.cjs` from the repository root. Install test dependencies with `npm ci --prefix tests` and Playwright browsers with `npm exec --prefix tests -- playwright install chromium webkit`.

Observed locally on Windows: 16 interaction checks pass across Chromium and WebKit. Chromium axe WCAG A/AA audit reports zero violations. Tests cover the intro order and 1,300 ms overload, XP choice, one demo crossing the fold, 1,300/300 ms scramble cadence, staged demo, Pricing route and history, hover tilt, footer movement/occlusion, mobile overflow, dialog Escape, and runtime errors. Reduced motion stops the animation loop.

The full 9.2-second halftone loop was captured as **276 consecutive frames at 30 fps**. All frames were reviewed in six contact sheets, including frames 240–275 across the dissolve. The water front advances and retreats; fine foam changes between frames. The closing dissolve blends two real wave states and is visible as a soft overlap, rather than a hard jump. This is transformed footage, not a fluid simulation. The wave source is credited in website/assets/NOTICE.md.

Evidence is generated locally under `test-results/website-v2/`: screenshots, accessibility.json, results.json, frames/0000.png–0275.png, frames-0.jpg–frames-5.jpg. Use `FRI_SKIP_FRAMES=1` for an interaction-only rerun after a change unrelated to the ocean renderer.

Bundled Windows WebKit does not decode this MP4 in the test environment: it displays the halftone poster while interactions and other motion continue. Chromium decodes and renders the video. Browsers without WebGL use the grayscale video fallback; Reduce Motion keeps a still image. Safari on actual Apple hardware still needs device verification.

The source quote is Steve Jobs's 2005 Stanford commencement address: https://news.stanford.edu/stories/2005/06/steve-jobs-2005-graduates-stay-hungry-stay-foolish . Motion references informed independently written effects; no paid example source was copied.

No analytics, signup backend, payment collection or calendar uploads are enabled. Premium is labelled Coming soon. Download links are prepared for v0.3.0 and are published only after its release assets are available. The macOS choices are labelled development builds.

Additional visual review: 25 ordered curtain frames, 10 scramble frames through the 300 ms transition and 15 demo states were captured in test-results/motion-review. All three contact sheets were inspected. Curtain closure covers the route swap and opens onto Pricing; the scramble resolves into the complete mission line; the demo enters, clarifies, saves and completes a plan. Linux CI download assertions now distinguish the supported Windows direct EXE target from the release/architecture chooser.
