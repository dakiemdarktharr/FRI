# Keyboard navigation and time selection

Windows 0.8.2 · Android 0.4.2 / versionCode 6 · browser calendar and standalone HTML.

## Interaction contract

The appointment editor has one full-width **Confirm** action. Its corner close button and Escape protect unsaved edits. Confirm still validates the title, asks for missing time/duration, and presents overlaps before saving. This replaces the old three-button manual-entry footer; staged multi-source imports remain available.

Time selection uses three wheel columns: hour, minute, AM/PM. Every minute is available. The central band marks the selected row. Confirm applies the value; closing or Escape leaves the existing value untouched. Midnight is 12:00 AM / 00:00 and noon is 12:00 PM / 12:00. The sheet scrolls on short viewports and follows the app theme, font and opaque surface rules.

On Android, the picker is a native React Native Modal, not a WebView. Wheel values expose adjustable accessibility actions. System Back dismisses the picker without changing the form; Back from an edited form asks before discarding. Moving the start date/time keeps the existing duration for ordinary appointments. Shared invitations still require explicit duration review. Calendar date selection retains the platform date picker.

## Keyboard map: Windows, browser and HTML

| Action | Keys |
| --- | --- |
| New plan menu | N |
| New schedule | Ctrl / Command + N |
| Search | /, Ctrl / Command + K or F |
| Settings | Ctrl / Command + comma |
| Toggle sidebar | Ctrl / Command + B |
| Cycle app regions | F6, Shift + F6 |
| Today | T |
| Feed, week, month, year | 1, 2, 3, 4 |
| Apply prepared sources | R |
| Shortcut reference | ? or Help → Keyboard shortcuts |
| Confirm current primary form | Ctrl / Command + Enter |
| Move through month dates | Arrow keys; Home / End for start/end of week |
| Previous / next month | Page Up / Page Down |
| Previous / next year | Shift + Page Up / Page Down |
| Move through feed cards | Up / Down, Home / End |
| Switch card details / completion | Left / Right |
| Move through open day tabs | Left / Right, Home / End |
| Close focused day tab | Delete |
| Search results | Down from field; Up returns to field; Enter opens |
| Menus | Up / Down, Home / End, first letter, Left / Right between top menus |
| Time wheels | Up / Down, Home / End, Page Up / Down; Left / Right between wheels; A / P in period |
| Close popup or return | Escape |

Single-character shortcuts can be disabled in Settings. Shortcuts do not interrupt text editing, contenteditable fields, IME composition, or an open modal. Native menu accelerators also respect an open editor. Browser/OS shortcuts may be reserved by the host; the visible menu remains available.

Tab and Shift+Tab remain available throughout. The skip link enters the calendar directly. Hidden mobile navigation is inert; showing it moves focus inside, and Escape returns to its toggle. Focus stays on the same task after completion and on a logical next task when a filter removes the completed card. Re-rendering tabs, source lists and widgets retains focus. Closing a modal resolves a replaced trigger instead of focusing a detached node.

## Desktop widget

- During area selection, arrows place a centered 360×360 area, Shift+arrows resize it, Enter creates it, Escape cancels. Pointer drawing remains supported.
- Focus the widget header to move with arrows; focus the resize handle to resize. Shift changes the increment from 10 to 40 pixels.
- Widget options support arrows, Home/End, Enter and Escape. Menu navigation does not move the widget. Removing a widget persists through the existing encrypted-state path.
- Periodic widget updates retain focus on a replacement integration button. Completing the last task moves focus to the create-plan action.

## Source and verification

Implementation: `preview/keyboard.js`, `preview/time-picker.js`, `preview/keyboard.css`, `preview/app.js`, `preview/chrome.js`, `desktop/widget-select.html`, `desktop/widget.html`, `mobile/src/components/TimeWheel.tsx`, `mobile/src/app/edit.tsx`.

Run from the repository root:

```powershell
node preview/build.mjs
npm test --prefix preview
$env:FRI_BROWSER='webkit'
node --test preview/keyboard.test.cjs
Remove-Item Env:FRI_BROWSER
node website/build.mjs
node website/verify-product.cjs
node desktop/prepare.cjs
$env:FRI_TEST_HIDDEN='1'
node --test --test-concurrency=1 desktop/desktop.test.cjs desktop/widget.test.cjs desktop/keyboard.test.cjs desktop/brand.test.cjs
npm run typecheck --prefix mobile
npm run lint --prefix mobile
```

Packaged verification sets `FRI_TEST_EXE` to the built `dist/win-unpacked/FRI.exe` and repeats the desktop keyboard/widget suite. Android build and device commands are in `mobile/README.md`. Evidence is in ignored `test-results/keyboard-*.log` and `test-results/time-picker-*.png`.

Observed before distribution: existing calendar/import/appearance regression suite, new keyboard/time-wheel cases in Chromium and WebKit, actual Electron keyboard widget creation/move/resize/removal, browser OCR and staged conflict handling, mobile typecheck/lint. Final native build/device and publication results are recorded in the release notes and Obsidian receipt.

This is scenario-based regression verification, not a claim that all possible interactions are defect-free. Full NVDA/TalkBack/VoiceOver review, physical Android external keyboards and native Apple binaries have not been certified by these automated checks. Windows remains unsigned; Android remains a development-key local alpha.

Reference patterns: [WAI modal dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/), [WAI menu](https://www.w3.org/WAI/ARIA/apg/patterns/menubar/), [React Native ScrollView](https://reactnative.dev/docs/scrollview), [React Native accessibility](https://reactnative.dev/docs/accessibility), [Expo SDK 58 router](https://docs.expo.dev/versions/v58.0.0/sdk/router/). These guide behavior; the app retains Fri's own typography and colors.
