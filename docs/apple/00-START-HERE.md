# FRI on Apple — Codex handoff

**Latest handoff (27 November 2026): [CODEX-APPLE-REBUILD.md](../../CODEX-APPLE-REBUILD.md), [0.8.2 port plan](10-082-REBUILD-PLAN.md), [build runbook](11-082-BUILD-RUNBOOK.md).** The paragraphs below retain earlier native receipts. Windows 0.8.2 / Android 0.4.2 are the current visual/interaction reference; native Mac 0.7.0 build 7 remains the baseline to port forward.

Research date: 2026-11-23; integration checkpoint: 2026-11-24. The native Xcode project and local verification are now included on `main`. See the [production readiness ledger](verification/PRODUCTION-READINESS.md) and [earlier receipt](verification/RELEASE.md). The earlier native implementation targeted Windows/Linux 0.5. The local 0.7.0 update implements the Cloud feed, calendar views and staged source workflow.

Windows 0.8.2 is the current first-plan reference; read [the exact rebuild specification](09-FIRST-PLAN-REBUILD.md) before the older chapters. The native Mac 0.7 build 7 remains the published native baseline; inspect its release verification and import addendum before starting. Preserve the shipped calendar behavior and Cloud/Ink/Teal light and dark design with an actual glass workspace and opaque controls. This handoff does not authorize new Day development. Marketing shares Cloud/Ink/Teal; Premium is **50,000 VND/month, coming soon**, without a payment backend.


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

## Original implementation prompt (historical)

> Inspect AGENTS.md, this handoff, source and the latest Windows release receipts. Create codex/apple-native. Implement macOS and iOS apps plus native WidgetKit extensions using the target structure below. Port and test every parity row, including incomplete-information intake, conflicts, imports and concurrent completion. Preserve the compact continuous day feed, week/month/year selector, opaque cards, date tabs and widget priority. Never substitute an Electron window for a WidgetKit extension or call an unsigned DMG an Apple release. Do not develop Day, collect appointment data, invent credentials or enable billing. Document unsupported platform behaviors and supply the closest OS-supported interaction. Update this ledger and Obsidian if available after each milestone. Produce build/test logs, signed artifact checksums and real-device evidence. Continue through all work possible with available credentials; report remaining blockers precisely.

## Two distinct deliverables

- Existing Electron Mac preview: quickest parity reference, built by current CI. Widgets are floating Electron windows; glass is under-window vibrancy. This is not the finished Xcode/WidgetKit product.
- Native Apple release: SwiftUI apps, shared Swift package and native extensions. A WKWebView wrapper alone does not supply native widgets or protected shared storage.

The original Windows handoff did not include an Xcode project or Apple runtime validation. The native project now exists under `apple/`; the verification ledger records completed local checks and the remaining signing, runtime and distribution gates. Commands in these guides are instructions, not execution receipts.

## 0.6.1 import parity update

Read [smart import](../smart-import.md) before building the next Apple client. Port the normalized records, missing-field cards, fixed-time conflict rules, deadline preparation planning, past filtering, ICS recurrence and synthetic tests. Native source access needs WKWebView/WKWebsiteDataStore with explicit user sign-in; keep cookies and API credentials in appropriate Keychain/App Group boundaries. Do not copy Windows ciphertext into a Mac/iOS keychain. On macOS Electron, verify source-browser menu access and repeated authenticated reads; Windows verification alone does not establish Apple support. The native app uses JavaScriptCore with the Windows planning rules and a separate WebKit data store per source host. A user can review visible website text before choosing local or optional OpenAI extraction.

## 0.7 source contract

Read [accepted design](../cloud-feed-redesign.md) and [intake contract](../smart-import.md) before porting. Add sources → local extraction first → essential-question cards → persistent prepared inbox. Only Refresh applies valid records; conflicts stay separate, fixed plans never move, repeated sources deduplicate, and past records are skipped. Port these semantics and tests, not the superseded immediate-import or mosaic UI. Preserve original-language event titles while keeping UI copy in English.
