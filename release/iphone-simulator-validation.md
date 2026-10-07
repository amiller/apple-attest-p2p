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

## Signed export follow-through

The iOS 27 archive was signed with the existing Xcode account and exported using
`method=app-store-connect`, `destination=export`, automatic signing, and team
`DC9JH5DRMY`. This saved a local IPA; it did not upload or submit beta review.
The initial signing attempt failed with `errSecInternalComponent`. Unlocking the
existing dedicated signing keychain using its already-authorized local mechanism
resolved it. No credential was printed or copied into source control.

[`iphone-app-store-export.json`](iphone-app-store-export.json) records version
0.1.0/build 3, the IPA/executable hashes, strict signature verification, production
App Attest and CDhash opt-in, `get-task-allow=false`, and zero provisioned device
identifiers in the distribution profile. The executable does not contain the
simulator fixture environment-variable selector. Build 3 is an export value,
not proof it is available for upload; check current App Store Connect state.

Eight existing contract tests using retained real iPhone evidence also passed:
correct iOS enrollment/assertions and network admission, modified/tampered or
unregistered code rejection, and rejection under the Mac key profile. The
fixture was captured from an ad-hoc iPhone build (validation category 5), **not**
this new build or a TestFlight-installed iOS 27 app. Results are retained in
[`iphone-cryptographic-tests.txt`](../data/ios-simulator-20261007/iphone-cryptographic-tests.txt).

Reproduction after a signed archive exists:

```sh
xcodebuild -project node/ios/AttestNode.xcodeproj -scheme AttestNode \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/AttestNode-iOS27-signed.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID -allowProvisioningUpdates archive
```

Export options used (local export only):

```xml
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>export</string>
<key>teamID</key><string>YOUR_TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>manageAppVersionAndBuildNumber</key><false/>
<key>uploadSymbols</key><true/>
</dict></plist>
```

```sh
xcodebuild -exportArchive \
  -archivePath build/AttestNode-iOS27-signed.xcarchive \
  -exportOptionsPlist build/TestFlightExportOptions.plist \
  -exportPath build/app-store-export -allowProvisioningUpdates
```

The live deployment must not be repinned to the iPhone executable. Its
`CDRegistry` admits one baseline, its adapter fixes the Mac ACL and signing
category, and its `ResearchBadges` fixes that adapter/category. The network
contract supports additional categories; an additive iOS route can share its
zero-scope peer network, but the relay, badge policy and account-upgrade policy
must explicitly support that route. In particular, a second team's differently
signed build and an Apple-processed TestFlight build cannot be assumed to share
a validation category. Preserve existing Mac membership/NFTs and test these
bindings before enabling iPhone admission.
