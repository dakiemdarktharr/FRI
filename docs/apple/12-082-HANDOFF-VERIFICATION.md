# Apple 0.8.2 handoff verification

Prepared on Windows, 27 November 2026. Reference application commit: `d31f0077745b85941b4fdd4e1bc3009de1e6a82b`. This receipt describes the handoff kit, not a completed native Apple port.

## Included and checked

- Root Codex entry prompt, file-level port plan, build/distribution runbook and links from the existing Apple guides.
- Canonical Cloud/Ink/Teal light/dark tokens, Be Vietnam Pro font paths/PostScript names/license, keyboard contract and synthetic interaction fixtures.
- Ready Xcode catalog containing iOS/macOS AppIcon sizes, FRIMark, FirstPlan and naive navigation symbols rendered from the canonical SVG geometry. The iOS icon is 1024×1024 RGB with no alpha channel. Native target membership remains an explicit integration step.
- Unmodified synthetic light/mobile and dark/desktop time-picker references, plus the complete existing standalone app HTML in the repository.
- Portable checksum/fixture/catalog checker, reproducible asset renderer, receipt generator, Mac environment/build/test driver, archive/export driver and DMG packager with separate Developer-ID and explicitly labeled local-development modes.
- Local signing/export examples containing placeholders only. Filled config, archives, derived data and receipts remain gitignored.
- Twenty-two acceptance rows begin as pending native verification; generated receipts begin as not-run. No Windows pass is copied into a native PASS field.

Validation commands used for the kit:

```sh
node --check apple/Tools/rebuild-handoff.cjs
node apple/Tools/rebuild-handoff.cjs assets
node apple/Tools/rebuild-handoff.cjs manifest
node apple/Tools/rebuild-handoff.cjs check
node apple/Tools/rebuild-handoff.cjs receipt
bash -n apple/Tools/rebuild-on-mac.sh
bash -n apple/Tools/archive-on-mac.sh
bash -n apple/Tools/package-native-mac.sh
```

Export plist syntax, local Markdown links, PNG dimensions/color mode, font PostScript names and repeatable asset output are checked separately during preparation. The `Apple handoff integrity` GitHub workflow repeats the portable manifest/fixture/catalog, shell syntax and plist checks on Linux.

## Must be verified on the Mac

Xcode compilation and project membership; Swift/CoreText integration; platform time controls; real Mac keyboard and VoiceOver; iOS Simulator interaction; signed shared-store WidgetKit; Share Extension; architecture/signature inspection; archive export; DMG mount/launch; notarization; data-preserving upgrade; and iOS distribution through the selected authorized channel. All are pending for the new native 0.8.2 port.

The kit does not alter native app behavior, regenerate the existing Xcode project, change signing identities, publish a new Mac installer or delete any installed version. Existing native receipts are retained as history. See [the port plan](10-082-REBUILD-PLAN.md) for exact current gaps rather than treating a successful build of the old source as parity.
