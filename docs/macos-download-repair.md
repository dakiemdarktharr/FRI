# macOS download repair

Date: 2026-11-23, Asia/Ho_Chi_Minh.

## Failure reproduced

The November 23 investigation examined the published v0.5.0 Electron DMGs. The native SwiftUI app builds separately in Xcode.

The Apple silicon download's SHA-256 is `09e39f13e488f3de3fb2566920df18d3b472f9c0a0fa03370251920dd43017fa`, matching GitHub's asset digest. The image mounts successfully, but the contained app fails `codesign --verify --deep --strict` with:

```text
code has no resources but signature indicates they must be present
```

The executable retains a linker ad-hoc signature with `Identifier=Electron`, `Info.plist=not bound`, no sealed resources and no TeamIdentifier. The older v0.4.0 artifact has the same failure. The workflow explicitly disabled signing and tested the source app before packaging, so passing CI and HTTP 200 downloads did not establish an installable Mac release.

## Repair

- `npm run dist --prefix desktop` now uses the Mac distribution pipeline on macOS. It refuses missing notarization credentials or a missing Developer ID identity, and requires signing.
- The app is signed and notarized before packaging. DMGs are also signed, notarized and stapled. DMG update metadata is disabled because stapling changes its bytes; ZIP updater metadata remains valid.
- Verification checks the actual DMG/ZIP contents, strict nested signatures, the FRI identifier, Developer ID authority, hardened runtime, stapled tickets and Gatekeeper. Final SHA-256 hashes are generated after stapling.
- CI tests the packaged app on the runner architecture. Publication requires both architectures and formats, a successful distribution receipt, matching hashes and a fresh trust assessment.
- Development builds use an explicit ad-hoc signature and a separate output directory/name. They cannot pass the publication receipt gate. They do not establish Gatekeeper acceptance for internet downloads.

## Local development check

```sh
npm ci --prefix desktop
npm ci --prefix tests
npm run dist:mac:development --prefix desktop -- arm64
FRI_TEST_EXE="$PWD/dist/mac-development/mac-arm64/FRI.app/Contents/MacOS/FRI" \
  node --test --test-concurrency=1 --test-name-pattern='native window|draw widget' \
  desktop/desktop.test.cjs desktop/widget.test.cjs
```

This does not disable Gatekeeper or remove quarantine attributes. Do not publish these development files as supported downloads.

## Observed verification

- The rebuilt Apple silicon DMG and ZIP both passed strict nested signature verification after mounting/extraction. The signature now binds `com.fri.calendar`, Info.plist and sealed resources.
- Two packaged application tests passed: calendar creation, IPC isolation, window controls, persistence after restart, widget creation, resizing, completion and removal.
- Sixteen additional tests passed for encrypted storage, concurrent edits, planning, network restrictions, material rendering and release credential/publication gates.
- An actual signed bundle copy was modified after signing; the verifier rejected its changed resource. The original downloaded v0.5.0 app was also rejected.
- A public build without notarization credentials failed before packaging. The development receipt was rejected by the publication gate. Workflow YAML parsed and `git diff --check` passed.
- The development DMG SHA-256 is `c8542f54ea3700767e14d94226e2d82fab886b40201b683cef5d19c5538014bb`; ZIP is `f7fd02e38c098f368c452da71b054c8b876212f4f6ad004bbc15641b0d9ca526`. These are local test artifacts, not a notarized release.

Signed production build, notarization service submission, Gatekeeper acceptance for a browser download, Intel runtime, remote CI and website publication remain unverified. No public release assets or production website files were changed in this repair session.

## Required account setup

Public Electron Mac builds require a Developer ID Application identity and notarization credentials for the release team.

The account owner must verify membership at [Apple Developer Account](https://developer.apple.com/account/) and select the enrolled team in Xcode. Install a Developer ID Application identity including its private key. Keep all passwords, private keys and certificate exports out of the repository and chat.

For a local release, store notarization credentials interactively in Keychain with `xcrun notarytool store-credentials fri-release`. Then run:

```sh
APPLE_KEYCHAIN_PROFILE=fri-release npm run dist --prefix desktop
node desktop/scripts/check-mac-receipt.cjs dist/mac-release
```

For the existing workflow, the repository owner configures `MAC_CSC_LINK` (the exported identity), `MAC_CSC_KEY_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` and `APPLE_TEAM_ID` as GitHub Actions secrets. Never put secret values in workflow YAML. The manual workflow's `release_tag` must match `desktop/package.json`.

Only after a signed release passes all checks should its DMG URLs be promoted in `website/page.html`. Rebuild the website and verify the actual downloaded files with quarantine intact. Test Apple silicon and Intel on matching hardware before claiming both runtime paths are verified.

References: [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [electron-builder v26 signing](https://www.electron.build/v26/docs/features/code-signing/code-signing-mac/).
