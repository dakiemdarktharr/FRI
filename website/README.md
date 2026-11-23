# FRI website

Production: https://fri-acne-a6cd.vercel.app

Open ../FRI-website.html directly, or run `node website/build.mjs` to rebuild it. The standalone file embeds the video, poster, pole logo, styles and scripts. The Vercel build serves public/index.html, public/pricing/index.html and the separately cached MP4.

The intro loads, opens a black screen and builds from one notification into a 1,300 ms burst. A single-action Windows XP-style popup opens the landing page. One full demo window begins halfway down the hero and is revealed as the visitor scrolls. Hero text cycles through Fri, its mission and the pole logo with 300 ms scramble transitions and 1,300 ms holds.

Real beach footage is processed to halftone every frame. The 9.2-second loop runs at 1.18 times the source speed; a soft closing dissolve avoids a hard cut. Footer tiles move continuously and fade/blur behind copy. The footer reveals beneath the main page. Pricing has its own URL, curtain transition and pointer-relative tilt. Premium is Coming soon; there is no payment or signup backend.

Reduced-motion users see a still ocean and still demo. A keyboard-focus-only motion control remains available for accessibility; the previously marked visual pause/replay/down controls are removed. The home page shows three download buttons. Windows downloads the x64 installer, macOS opens a choice between Apple silicon and Intel, and Linux downloads the standalone HTML app.

Run `node website/verify-v2.cjs` after installing tests dependencies and Chromium/WebKit. Set FRI_SKIP_FRAMES=1 for an interaction-only run. See ../docs/web-verification-2026-11-23.md for observed results and platform limits. Asset provenance and license are in assets/NOTICE.md.
