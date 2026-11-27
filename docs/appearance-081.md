# Appearance and Vietnamese typography · 0.8.1

27 November 2026. Windows 0.8.1 and Android 0.4.1/code 5 refine the existing calendar without changing calendar storage, import decisions, widget IDs or account behavior.

## Design decisions

- Dark mode separates charcoal background (#14181F), opaque cards (#222833), and raised controls (#2C3441). Primary text is #F2F4F8, secondary text #B3BECE and accent #75D8CC. Only the main workspace retains its native glass material.
- Be Vietnam Pro replaces Inter in the website, browser calendar, Electron app/auxiliary windows/desktop widgets, React Native screens and Compose widget editor. Regular, SemiBold and Bold are bundled locally. Android launcher widgets and OS-owned controls use supported system typography.
- Input outlines and completion rings have stronger contrast. Selected navigation has an edge cue; active tabs have an underline. Android selected calendar cells use dark text on the pale teal accent.
- Year dates increase from 6–7px to 11–12px. Adjacent-month placeholders in the year view are blank; clickable adjacent dates in the month view keep readable text. Month cards align at the top and reserve equal-height week rows.
- Android month rows use a fixed vertical gap instead of a percentage that inflated empty space. Native widget-editor selection borders use the explicit Fri control color.
- Narrow titlebars use the existing refresh symbol and accessible label instead of wrapping “Add ready plans” across three lines. Event titles have room for Vietnamese accents and longer names.
- Day suggestions, update controls and native widget configuration use the current theme rather than leftover colors. Calendar cards and buttons remain opaque.

Canonical typography, sizes, license and palette: `brand/README.md`. Canonical final browser/Electron visibility rules: `preview/contrast.css`. Apple rebuild contract: `docs/apple/09-FIRST-PLAN-REBUILD.md`; no native Apple build is claimed by this Windows-hosted update.

## Verification

- 39 calendar UI tests pass. The new appearance test checks text contrast in nine views under both light and dark modes, completion-control boundary contrast, local font loading and responsive feed widths. Chromium and WebKit pass.
- All three font weights include the complete Vietnamese base-letter and U+1EA0–U+1EF9 set, plus the combining marks used by NFD Vietnamese. No glyph subsetting was applied.
- Chromium and WebKit website checks pass at six viewport widths. Product-story/navigation checks cover eight sections at four widths and 90 sampled motion frames per engine. Chromium axe checks report no violations on the tested pricing/home states. Local Windows WebKit cannot decode the bundled video; Linux CI is the playback gate.
- The packaged Windows app passes calendar/menu/persistence, optional onboarding and widget draw/Done/resize/restart/remove tests. A separate packaged appearance check verifies opaque dark cards, on-accent text and the actual bundled font loading under CSP. The package audit compares fonts to canonical bytes and excludes obsolete Inter resources and credentials.
- Android TypeScript and ESLint pass; nine Kotlin unit tests pass. The optimized x86_64 APK was installed over the existing app on API 35: calendar data and launcher widget IDs survived. Feed/calendar light and dark modes, Vietnamese titles, selected-date contrast and the native widget editor were inspected. Calendar geometry checks confirmed all 30 visible dates were square (within 2px) and the following heading was 49px below the last row. The widget editor was cancelled without adding a new instance; the existing launcher widget remained. ARM64 was built, not run on a physical phone.

These are observed representative screens and regression checks, not a claim that every device, backdrop or possible interaction has been inspected. Native compositor optics were preserved, not re-certified from browser screenshots.

## Reproduce

```powershell
node preview/build.mjs
npm test --prefix preview
$env:FRI_BROWSER='webkit'
node --test preview/appearance.test.cjs
Remove-Item Env:FRI_BROWSER
node website/build.mjs
node website/verify-responsive.cjs
node website/verify-positioning.cjs
npm run dist --prefix desktop
node desktop/verify-package.cjs
$env:FRI_TEST_HIDDEN='1'
$env:FRI_TEST_EXE=(Resolve-Path dist/win-unpacked/FRI.exe).Path
node --test --test-concurrency=1 desktop/desktop.test.cjs desktop/widget.test.cjs desktop/brand.test.cjs
Remove-Item Env:FRI_TEST_EXE
npm run typecheck --prefix mobile
npm run lint --prefix mobile
```

Android native build variables and commands remain in `mobile/README.md`. Run incremental prebuild before building; the preparation step removes only known obsolete generated Inter font files. Build x86_64 and ARM64 separately. Do not clear application data or regenerate the existing development signing key.

Evidence is in ignored `test-results/dark-type/` and `desktop/test-results/`. Private user data is not a test fixture. Windows remains unsigned; Android APKs remain development-key local alpha builds. The existing verified native Mac download is unchanged.

## Distribution artifacts

Both APKs and the standalone HTML include the font license. Windows is 334 KB smaller and each APK about 442 KB smaller than the preceding release; no calendar capability was removed. `SHA256SUMS.txt` accompanies release v0.8.1.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| FRI-0.8.1-win-x64.exe | 136258867 | `5133acab69f769e1fd6ea071314edeba7538096d31b23b47f7c29d85ae34d506` |
| FRI-0.4.1-android-arm64.apk | 40850466 | `31605b53dd233430f7e811f314ba54ca6112583f6eeb4df588348b17d04caa10` |
| FRI-0.4.1-android-x86_64.apk | 41868963 | `0cdf6dff46563906379e8e333adaace11f400a5bfa2391802e6fad69454fd85b` |
