# FRI on Apple — Codex handoff

Research date: 2026-11-23. This is an implementation and acceptance specification, not a claim that native Apple targets already exist. Windows 0.4.0 is the reference; inspect its final release verification before starting. Day development is deferred. Preserve shipped calendar behavior and the approved monochrome app. Marketing uses white/marsala; Premium is **50,000 VND/month, coming soon**, without a payment backend.

Read in order:

1. [Parity ledger](01-PARITY.md): Windows features, Apple equivalents, required proof.
2. [Architecture and data](02-ARCHITECTURE-DATA.md): storage, concurrency and migration.
3. [Xcode build](03-XCODE-BUILD.md): project targets, capabilities and commands.
4. [WidgetKit](04-WIDGETKIT.md): timelines, Done, placement and lifecycle.
5. [Glass and design](05-GLASS-DESIGN.md): native material and responsive behavior.
6. [Integrations and privacy](06-INTEGRATIONS-PRIVACY.md).
7. [Distribution](07-DISTRIBUTION.md): signing, installers and safe upgrades.
8. [Acceptance and sources](08-ACCEPTANCE-SOURCES.md).

Also read ../fri_design_guidebook.pdf, ../privacy.md, ../../desktop/store.cjs, ../../preview/app.js and ../../preview/planning.cjs. The renamed PDF preserves authorship and bytes; it does not override current Apple documentation or the user's brief.

## Prompt for Codex on the Mac

> Inspect AGENTS.md, this handoff, source and the latest Windows release receipts. Create codex/apple-native. Implement macOS and iOS apps plus native WidgetKit extensions using the target structure below. Port and test every parity row, including incomplete-information intake, conflicts, imports and concurrent completion. Preserve the duration-based mosaic, equal gaps, date tabs and widget priority. Never substitute an Electron window for a WidgetKit extension or call an unsigned DMG an Apple release. Do not develop Day, collect appointment data, invent credentials or enable billing. Document unsupported platform behaviors and supply the closest OS-supported interaction. Update this ledger and Obsidian if available after each milestone. Produce build/test logs, signed artifact checksums and real-device evidence. Continue through all work possible with available credentials; report remaining blockers precisely.

## Two distinct deliverables

- Existing Electron Mac preview: quickest parity reference, built by current CI. Widgets are floating Electron windows; glass is under-window vibrancy. This is not the finished Xcode/WidgetKit product.
- Native Apple release: SwiftUI apps, shared Swift package and native extensions. A WKWebView wrapper alone does not supply native widgets or protected shared storage.

No Xcode project, provisioned App IDs, distribution certificates or physical-device validation exist in this Windows handoff. Create and verify them on the Mac. Commands in these guides are instructions, not execution receipts.

## 0.6 import parity update

Read [smart import](../smart-import.md) before building the next Apple client. Port the normalized records, missing-field cards, fixed-time conflict rules, deadline preparation planning, past filtering, ICS recurrence and synthetic tests. Native source access needs WKWebView/WKWebsiteDataStore with explicit user sign-in; keep cookies and API credentials in appropriate Keychain/App Group boundaries. Do not copy Windows ciphertext into a Mac/iOS keychain. On macOS Electron, verify source-browser menu access and repeated authenticated reads; Windows verification alone does not establish Apple support. No SwiftUI/WidgetKit/Android implementation of this new import flow is claimed.
