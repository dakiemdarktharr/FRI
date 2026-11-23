# Fri website design preview

Open [FRI-website.html](../FRI-website.html) directly in a browser. It embeds the ocean image, logo, styles and scripts; viewing needs no server or internet. Download links and the quotation open external pages.

## Design

The opening moves from noise to quiet: resource loading, black screen, one message, a deadline popup, a calendar, then a 1,300 ms burst of overlapping cards. A single-action modal says **“Everything wants your attention. Your life deserves it.”** The action is **“Make room.”**

The page presents the ocean hero, a staged Fri demonstration, What it does, How Fri works, and the marsala footer: **“Less noise. More life.”** Page copy is English, using headings and functional labels rather than supporting paragraphs.

The utility-pole mark is an original minimal SVG based on the four user-supplied reference photos. White and `#955251` are the brand colors. The demonstrated app stays monochrome. The sea is a generated aerial photograph animated with a small WebGL displacement shader, not a video file. It gently advances and recedes at the shore. Unsupported WebGL falls back to the embedded photograph.

The demo is a choreographed, read-only presentation with chapter, replay and pause controls. It enters “Coffee with Jamie,” asks for the missing time, adds the appointment and completes a task. It does not modify the desktop application's calendar.

## Scope and behavior

- Windows download points to the published `FRI-0.2.0-win-x64.exe`.
- macOS is detected, then the visitor chooses Apple silicon or Intel; browser platform strings cannot reliably identify Mac CPU architecture.
- Other platforms receive the available desktop download choices. No Linux/iOS installer is claimed.
- Pricing and Sign up open honest preview-state dialogs. Prices, account creation and payment processing are not implemented.
- No analytics, cookies, forms that send data, autoplay audio or OS notification permission.
- Escape/Skip intro bypasses the opening. The single-button question traps keyboard focus. Native dialogs support Escape, click outside and focus restoration.
- Reduced motion starts ocean/demo paused and replaces the rapid cascade with a static arrangement. Both animations can be paused independently.
- Replay the beginning replays the opening; it is not suppressed with local storage.

## Build and verify

```powershell
node website/build.mjs
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
node website/verify.cjs
```

The builder creates `FRI-website.html` (~442 KiB). It does not alter `index.html`, `FRI-liquid-glass.html`, native app sources or installers.

Verification exercises real browsers over `file://`: opening order and burst timing, modal focus, platform downloads, demo chapters, pause/replay, small screens, reduced motion and error-free execution. It also runs axe WCAG A/AA checks in Chromium. Screenshots and receipts go to ignored `test-results/website/`.

Verified 23 November 2026: **18 checks passed** across Chromium and WebKit, including ocean playback, intro replay and 320/390 px layouts. Chromium axe reported **zero automated WCAG A/AA violations**. Desktop/mobile screenshots were visually reviewed. This is not a complete manual accessibility audit.

## Asset provenance

- `assets/ocean-original.png`: generated with OpenAI imagegen on 22–23 November 2026. `ocean.webp` is the compressed copy embedded in the standalone file.
- `assets/fri-pole.svg`: original authored vector interpreting the supplied pole photographs; no photo is embedded in the logo.
- A separate Figma proposal was created at [node 7:2](https://www.figma.com/design/faLZGmUwp1dqn4p5poiolg?node-id=7-2). The Starter plan tool limit prevented export/review. The HTML SVG is separately authored, not a claimed Figma export.
- Footer quotation: “Our life is frittered away by detail.” — Henry David Thoreau, *Walden* (1854), [Project Gutenberg text](https://www.gutenberg.org/cache/epub/205/pg205-images.html). The attribution is linked in the page; it is not a testimonial or endorsement.
- Download assets confirmed against [FRI v0.2.0](https://github.com/dakiemdarktharr/FRI/releases/tag/v0.2.0).

The website is a local design review, not a deployed marketing site. After the web design is approved/completed, the requested next milestone is **Create FRI widget on desktop**.
