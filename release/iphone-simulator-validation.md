# iPhone participant validation — 7 October 2026

The iPhone app now opens directly into the participant flow. It creates and
retains a participant name, uses the pinned release network, and requests the
shared testnet key and participant NFT through the shared node implementation.
No configuration editor or Listen/Connect buttons are presented. Participation
is foreground-only. A bounded JSON-lines report can be shared or copied from the
app, including OS/app versions, the failed Apple operation and nested error codes.

**Not yet a TestFlight release.** The configured deployment currently admits the
Mac release's executable and Mac attestation profile. An iPhone executable is
not interchangeable with that baseline. Admission and signing must be completed
without invalidating the running Mac network. The simulator success scenario
uses injected events: it does not attest, obtain a key, or mint an NFT.

Evidence: [`data/ios-simulator-20261007/reviewed`](../data/ios-simulator-20261007/reviewed),
with source hashes and unsigned device archive hash in
[`source-manifest.json`](../data/ios-simulator-20261007/source-manifest.json).

## Observed checks

- Xcode 27 (27A266a) on mini-mesh; dedicated iPhone 17 simulator, iOS 26.5 (23F77).
  Only this simulator runtime was installed. Tests copy sources and lower the
  copied project's deployment target; the production target remains iOS 27.
- Five XCTest UI checks: attesting, claimed, network retry, Apple failure/report
  sharing, and the actual unsupported-simulator path plus persistent participant
  identity across relaunch. The first four inject labeled events; the fifth
  exercises the real support check without network requests.
- Share → Copy was tapped by UI automation. The simulator pasteboard was read
  and parsed: the report contained `attestKey`, Apple code 0, nested
  CryptoTokenKit code -3, and its explicit simulator-scenario marker.
- Nineteen injected callback checks cover success, asynchronous completion,
  Apple errors 0–4 and retry classification, missing results, duplicate callbacks,
  timeout, late completion after timeout, overlapping operations, and bounded
  domain/code-only error-chain extraction. These exercise the callback bridge
  used by the node; they do not emulate Apple's attestation cryptography.
- The unsigned iOS 27 device archive and shared-source Mac compile check passed.
  Nineteen existing Python profile/payload tests passed.

Apple calls now log `generateKey`, `attestKey`, or `generateAssertion` separately.
An operation timeout prevents further native calls through that bridge instance,
including after a late callback. The iPhone flow stops on terminal Apple errors
instead of endlessly calling them connection failures. The enrollment context is
saved before attestation so service-unavailable retries retain the same key/hash
across restarts. Full fault-injection coverage of persisted enrollment and the
complete network/claim loop remains outstanding.

## Reproduce on the Mac

Use a dedicated booted simulator; keep other people's simulator sessions intact.
From the source checkout:

```sh
python3 scripts/release/test_ios_simulator.py \
  --device YOUR_DEDICATED_SIMULATOR_UUID --runtime 26.5 \
  --out build/iphone-simulator-run
```

The output directory must be new. It retains the exact Xcode command, XCTest
result bundle, summary, screenshots, native-test output, and the copied report.
Production build:

```sh
xcodebuild -project node/ios/AttestNode.xcodeproj -scheme AttestNode \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/AttestNode-iOS27.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

This archive is unsigned, not installable distribution evidence. The actual
version/build number must be selected against current App Store Connect state.

## Findings preserved

The initial simulator install was rejected because the Info.plist hardcoded iOS
27 despite the simulator-only deployment override. The manifest now uses the
project deployment setting. The first sharing assertion incorrectly queried
Copy as a button; inspection established it was a share-sheet cell, and the
corrected test tapped it and verified the clipboard. Screenshot review found
that the simulator label could scroll away; it is now pinned above the content.

## Remaining acceptance

Sign/export/upload using the existing authorized App Store Connect account;
check the installed Apple-distributed executable and attestation profile; admit
it under a compatible network policy; exercise a physical iOS 27 device through
join, receipt verification, NFT mint, restart, and report sharing. Complete beta
review/external group setup and verify the resulting friend-accessible link.
The iPhone developer-upgrade file UI is not yet implemented. Do not claim the
full Level 2 iPhone journey from the shared underlying code alone.
