# Fri typography

Be Vietnam Pro is Fri's brand family from Windows 0.8.1 / Android 0.4.1 onward. Its open counters and generous Vietnamese diacritics support a fuller, clearer reading rhythm. Font files are bundled locally; the app never requests a font CDN.

| Role | Weight | Size |
| --- | --- | --- |
| Web display | 700 | Fluid, 48–152 px |
| Section headline | 700 | Fluid, 34–59 px |
| App page title | 600 | 28–34 px |
| Card title | 600 | 16–18 px |
| Body / fields | 400 | 16–17 px |
| Button / navigation | 600 | 14–16 px |
| Essential metadata | 400 | 13–14 px |

Use sentence case. No decorative subtitle, eyebrow, tagline inside functional screens, or duplicate action. Keep event metadata, validation, permission scope and billing facts. Place those facts at the relevant decision rather than beneath every heading.

Web, Electron and React Native use locally bundled static 400/600/700 weights. Use line-height 1.2–1.25 for large headings and 1.4–1.55 for titles/body so stacked Vietnamese accents have room. Do not transform text into all caps to create hierarchy. Android system widgets use the launcher's supported sans family with matching hierarchy; Glance does not support arbitrary bundled fonts. Native pickers and system menus keep platform typography.

Source: https://github.com/bettergui/BeVietnamPro · https://github.com/google/fonts/tree/main/ofl/bevietnampro
License: SIL Open Font License in `fonts/be-vietnam-pro/OFL.txt`. TTFs are the complete official Regular, SemiBold and Bold files. WOFF2 files are lossless fontTools/Brotli conversions with no glyph subsetting. The 90 U+1EA0–U+1EF9 characters plus Vietnamese base letters were checked in all three weights. `typography.cjs` is the shared build source; the ESM wrapper supports website/preview builds.

Legacy Inter files remain as historical release assets. Native Apple currently uses platform typography; the handoff describes how to adopt this new family. Do not copy them into new Windows/Android packages.

## Naive identity · first-plan release

`fri-mark.svg` is the canonical original mark. `first-plan.svg` is the optional welcome illustration. `symbols.json` contains the uneven but readable navigation pictograms. Keep the slight irregularity in the paths; typography and layout stay steady. There are no imported competitor marks.

Run `node brand/build.cjs` after installing `tests/` Playwright and Chromium to render native icons and React Native assets. Run the preview and website builders to embed vectors. Windows widgets embed the same SVG directly to keep their strict offline content policy. Be Vietnam Pro supplies the text; naive design remains confined to the symbols.

Logo and illustration copyright Fri contributors; third-party font license remains unchanged.

## Dark appearance

Charcoal background #14181F, opaque cards #222833, raised controls #2C3441, primary text #F2F4F8, secondary text #B3BECE, teal #75D8CC with #14181F text, tint #203D3B. Separators use #465368; editable/control edges use #7D8BA1. Only the main workspace composites native glass. Do not reduce opacity on whole cards or on readable calendar dates.

Use shape/underline/focus as well as color for selected navigation and dates. Focus rings are 3px. Calendar year dates use at least 11px on narrow screens; do not scale the whole calendar down. The website remains light with a dark footer; it uses the same font family and teal identity.
