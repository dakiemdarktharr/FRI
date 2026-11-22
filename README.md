# Fri

Fri is a personal calendar that makes room for appointments, focused work, and the everyday things that matter.

**Latest interface preview:** open [FRI-liquid-glass.html](FRI-liquid-glass.html). This separate, self-contained HTML explores the new sidebar/main-space layout, smoked Liquid Glass, beige typography, marsala accents, multiple day tabs, and a duration-sized appointment mosaic. The sidebar runs a slow beige/marsala ShaderGradient. Day, the bird companion, sits beside Up Next and the widget gallery.

The earlier working V1 remains in [index.html](index.html), with sources, scheduling logic, calendar export, and its existing data model. The new preview has its own local data and is intended for visual approval before native app integration.

## Try the new interface

Double-click `FRI-liquid-glass.html`, or open `/FRI-liquid-glass.html` on the local server described below. The file embeds its assets and renderer and works offline. Start on today, open another day with **+** beside the tabs, and close a day with its **×**. Use **Your way** for layout, editing and bulk deletion. **Settings** changes sidebar background, uploaded image, accent, motion, transparency and text size.

**Add → name and details → Add another → Done** gathers a batch. Day asks for missing time and duration one card at a time, then checks overlap before placing the appointments on the calendar. Complete the individual tasks to unlock the day ring. Delete offers Undo. `N` opens a new appointment, `/` searches, and Escape closes a dialog.

Up Next uses the local calendar. Weather, Maps, Spotify and Health show clearly labeled sample content. Day's conversation is a local interaction demo; voice entry and spoken playback depend on browser capabilities. Accounts, connected services, native desktop transparency, installers and updates belong to the later app phase.

Design decisions, source research, the ten wireframe regions and native handoff notes are in [Liquid Glass research](docs/liquid-glass-research.md).

To rebuild or test the preview:

```powershell
npm ci --prefix preview
npm run build --prefix preview
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix preview
$env:FRI_BROWSER = 'webkit'
npm test --prefix preview
Remove-Item Env:FRI_BROWSER
```

Verified on Windows: **8 scenario tests in Chromium and 8 in WebKit**, covering offline loading, duration/area ordering and equal gutters, batch review, overlap, editing/deletion/undo, completion gating, tabs and calendar navigation, hover timing, search, settings/image persistence, widgets, Day and accessibility semantics. Separate visual checks passed at 320/360/390 px. Shader pixels change with motion enabled and remain stable under Reduce Motion; loading makes zero external requests. Automated contrast checks reported no violations but left translucent regions for manual review; this is not a claim of full accessibility conformance.

Authoring files and dependency lockfile live in `preview/`. The output includes [third-party notices](preview/THIRD-PARTY-NOTICES.txt). The reusable `moving_gradient_bg` skill is installed locally with canonical ID `moving-gradient-bg`.

## Run the earlier V1

Open `index.html` directly in a modern browser. The app and sample assets are self-contained. For a stable storage origin and to try public calendar sources, run this command from the repository root:

```powershell
python -m http.server 8000 --bind 127.0.0.1
```

Open [Fri on localhost](http://127.0.0.1:8000/). The demo day is Monday, November 23, 2026 in `Asia/Ho_Chi_Minh`. Use **Settings → Manage data → Empty calendar** to start with your own calendar.

## Calendar and widgets

- **Day** opens first. Activities appear as posts with a time tile, title, and a check box for each trackable item. Hover for 300 ms to preview details or open the post by clicking, tapping, or pressing Enter.
- **Month** and **Year** use rounded square tiles. The month tiles bobble when the pointer enters and show a cursor-following agenda preview after 500 ms. Pick a month or day to go one level deeper. Use the arrow keys to navigate days in Month.
- The progress ring tracks appointments, flexible tasks, nested activities, and deadlines. The day-level check unlocks when every trackable activity is complete. Reopening an activity clears the day-level completion. Travel and on-site context appear in the feed and progress is unchanged by them.
- The square **widget** shows progress and the next activity. Open it to expand the upcoming stack, then select an item to open its details. **Widgets** includes a lock screen preview and system tint. Native widgets and background notifications belong to later platform releases.
- **Settings** includes alternate palettes, light and dark appearances, and reduced transparency. The app uses the Apple system font where available and platform fallbacks elsewhere. The calendar respects reduced motion.

The motion treatments are implemented with CSS and the Web Animations API. [Motion references for bobble](https://motion.dev/examples/react-bobble-hover), [cursor-following previews](https://motion.dev/examples/vue-cursor-hover-follow), [stagger](https://motion.dev/examples/vue-staggered-grid), [post expansion](https://motion.dev/examples/js-app-store-layout), and the [widget stack](https://motion.dev/examples/vue-notifications-stack).

## Add appointments and sources

Choose **Add appointment** and enter a name. Use **New appointment** to add another, then choose **Done**. Fri asks for any missing or invalid date, start time, or end time one card at a time. The full batch goes on the calendar after the final answer. Closing or reloading keeps the draft.

Use **Add sources** to stage images, text, and calendar links. The sample batch includes two images, an ICS calendar, and a login-required source. Public ICS and JSON-LD depend on the source’s browser access policy. Uploaded images have a local preview and go through manual review. **Plan tasks** previews schedule changes, explains issues, and applies a validated revision before exporting generated sessions as ICS.

## Verify

The app has no install step. The test suite uses Node.js 24, Playwright, and a local HTTP server started by the tests.

```powershell
npm ci --prefix tests
npm exec --prefix tests -- playwright install chromium webkit
npm test --prefix tests
$env:FRI_BROWSER = 'webkit'
npm run test:browser --prefix tests
Remove-Item Env:FRI_BROWSER
```

Run `npm run test:domain --prefix tests` for calendar and scheduling logic alone. [GitHub Actions](.github/workflows/web.yml) also runs both browser engines. [Architecture and technology](docs/technology.md) covers the implemented stack, data contracts, and platform roadmap.

Verified on Windows with 14 domain cases and 19 browser cases each in Chromium and WebKit. Coverage includes the solid palette, preview delays, square tile layout, keyboard and 360 px touch navigation, completion persistence, widget navigation, and the appointment, sources, and planner workflows.
