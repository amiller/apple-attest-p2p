# Mac release and TestFlight checklist

Status, 6 October 2026: release engineering in progress. The existing peer demo ran
successfully on Base Sepolia; this branch is not yet the zero-setup public application.
Do not label its CLI bundle as a finished one-click release.

## Build without an Apple account

On an Apple Silicon Mac with the exact Xcode/SDK/compiler in `toolchain.json`:

```sh
python3 scripts/release/build_mac.py --out build/unsigned
python3 scripts/release/check_repro.py --out build/repro
```

Choose unused output directories. Set `DEVELOPER_DIR` to the matching Xcode when
several are installed. The scripts fail on toolchain drift. They compile the
existing peer with optimization, a fixed module name, stable relative source
names, path remapping and no code signature. No package downloads are needed.
The unsigned bundle cannot run App Attest: that requires signing/provisioning.

`build-manifest.json` records source commit, dirty state of build inputs, hashes of all direct
build inputs, flags, toolchain, bundle identity/version, and every output file.
`check_repro.py` copies build inputs to two differently named roots, uses separate
module caches, and compares all unsigned bundle files. This is a same-host test;
independent builders must compare their own manifests too. A GitHub workflow or
provenance statement is not itself proof of reproducibility.

Measured on mini-mesh: both builds matched. Unsigned executable SHA-256:
`89697437b904571409a94ada5f64a68c9e72078b2606ee9c64bb619adb635f72`.
This value applies to the present CLI sources, not future GUI releases.

## Fork and build with GitHub resources

1. Fork the standalone `apple-attest-p2p` repository once published. The local
   source repository currently has no GitHub remote; no workflow has run there yet.
2. Enable Actions. `mac-build.yml` builds on `xcode-27` without Apple credentials.
   GitHub's image moves; the checked-in toolchain lock must still match. Change
   that lock only as a reviewed build input, then obtain fresh measurements.
3. Create an `apple-release` GitHub environment restricted to reviewed release
   refs; protect it against untrusted branches. Forks do not inherit secrets.
4. Add the following secrets and variables. Private keys are required, not just IDs.
5. Run **Signed Mac candidate** manually on the reviewed commit. It builds,
   signs, notarizes, staples, verifies Gatekeeper, and uploads a candidate ZIP
   plus checksums and evidence. It does not tag or publish an unfinished app.

| Kind | Name | Value |
|---|---|---|
| Secret | `MAC_CERTIFICATE_P12_BASE64` | Exported Developer ID Application certificate **with private key**, base64 |
| Secret | `MAC_CERTIFICATE_PASSWORD` | Password protecting that P12 |
| Secret | `MAC_PROFILE_BASE64` | Developer ID provisioning profile granting CDhash, base64 |
| Secret | `ASC_KEY_P8_BASE64` | App Store Connect API private key authorized for notarization, base64 |
| Variable | `APPLE_TEAM_ID` | Your team ID |
| Variable | `APPLE_BUNDLE_ID` | Your explicit App ID's bundle identifier |
| Variable | `MAC_SIGNING_IDENTITY` | Full `Developer ID Application: …` certificate identity |
| Variable | `ASC_KEY_ID`, `ASC_ISSUER_ID` | API key ID and issuer ID |

The signing job uses a temporary keychain, deletes it in `finally`, and runs on
an ephemeral hosted runner. It does not run on PR events. Actions are pinned to
commit IDs. Configure GitHub environment protection before adding secrets.

Changing the signing team does not require changing executable source. Changing
bundle metadata changes its sealed hash and may require a distinct approved
baseline under the current registry rules. Successful building/signing does not
automatically admit a fork to the shared network.

For local signing, use `scripts/release/sign_mac.py --help`. Unlock an existing
keychain in the same session beforehand. Development mode creates a **private**
archive that may embed device identifiers; never publish it. Developer ID mode
requires an all-devices profile and successful notarization. The script emits
only the required entitlements and never enables debugger access.

### Xcode managed signing alternative (measured locally)

Xcode's saved account session successfully exported the development-signed
candidate under **Developer ID Application: Honey Badger Coop. Labs Inc.
(DC9JH5DRMY)** even though the local keychain listed no Developer ID private key.
The exported executable matches the reproducible unsigned payload and produced
verified category-6 App Attest evidence. Apple accepted a notarization upload;
processing/approval is tracked separately.

```sh
python3 scripts/release/export_mac_xcode.py --app build/development/Node.app \
  --team DC9JH5DRMY --out build/developer-id
python3 scripts/release/export_mac_xcode.py --app build/development/Node.app \
  --team DC9JH5DRMY --out build/notary --submit-notarization
# After Apple finishes processing:
xcodebuild -exportNotarizedApp -archivePath build/notary/Node.xcarchive \
  -exportPath build/notary/notarized
```

This wrapper accepts `ASC_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID` instead of a
saved Xcode login. The API-key version is not yet tested on GitHub. It still
requires an initially signed app archive and a preexisting App ID with the
capability enabled; do not describe it as a fully verified key-ID-only fork flow.
The certificate-based workflow above remains a separate, unrun CI configuration.

## Reproducibility and signer independence

Keep three checks distinct:

- Rebuild the same source with the pinned compiler/SDK and compare unsigned bytes.
- Check the shipped bundle's signature, entitlements, resources, CDHash and
  notarization. `verify_signed_payload.py` compares every original executable byte,
  allowing only an appended signature load command and validated LINKEDIT sizes.
  The signing script also checks original resource hashes. This narrow comparator
  deliberately rejects unexpected layouts rather than ignoring new differences.
- Capture live App Attest evidence from that exact distributed app, bind its RP
  identity and CDHash to the appropriate policy, and demonstrate network admission.

Final ZIP bytes, timestamped signatures, provisioning profiles and notarization
tickets are not expected to reproduce independently. Do not strip arbitrary
differences or call two independently compiled apps equivalent merely because
their source commit matches. The current code-page comparison handles specific
re-signing differences, not arbitrary compiler output differences.

Bitcoin Core is a useful precedent: its documented Guix release process separates
reproducible unsigned macOS output from attaching signatures. Our Swift/DeviceCheck
app still trusts Apple's pinned binary toolchain and SDK; it is not a bootstrappable
Guix build.

## Release gates

- [x] Locate current implementation and successful Base Sepolia peer evidence.
- [x] Build the unsigned Mac peer twice from isolated paths; compare bytes.
- [x] Add credential-free CI and a separate signing/notarization candidate job.
- [ ] Run the workflow on an independent GitHub host and compare with the mini.
- [x] Unlock existing development keychain; sign and run the new candidate.
- [x] Match unsigned payload to signed executable; negative mutation tests pass.
- [x] Capture actual App Attest and verify Apple chain, nonce, production profile,
      Mac ACL and code-page/CDHash correspondence. Category 3 was observed; this
      is development signing, not Developer ID distribution. No chain transaction
      was submitted by the capture harness.
- [x] Export through Xcode managed Developer ID signing and capture category-6
      evidence. The deployed Mac adapter pins category 3, so the live network
      still needs a separately tested category-6 admission configuration.
- [x] Replay the real Developer ID enrollment through the Solidity adapter;
      accept under category 6 and reject under category 3. Register both the
      development and Developer ID copies under one code baseline successfully.
- [x] Submit the archive for notarization using the saved Xcode account. The
      submission succeeded; the most recent export check still says processing.
- [ ] Notarize/staple; browser-download and
      open the exact ZIP in a clean Mac account.
- [ ] Implement the first-run states in `user-flow.md` and a durable HTTPS relay.
- [ ] Resolve persistent identity, assertion ordering, uncertain transaction
      recovery, certificate expiry and bounded retry behavior.
- [ ] Resolve faucet recipient semantics: the current relay is Request.owner,
      so simply invoking Claim would send assets to the sponsor, not the user.
- [ ] Resolve group-key loss: current listen cannot resume after all RAM holders
      exit while the old key remains committed. Do not silently start a new network.
- [ ] Test restart, lock/unlock, disconnect/reconnect, login launch and update.
- [ ] Tag reviewed source; publish ZIP, checksum, source/build manifests,
      network policy/configuration, known limits, and measured results.
- [ ] Friend signs a copy; independently verify its evidence and peer exchange.

## TestFlight is an active release track

Yesterday's retained record confirms **AppAttest Lab dsmack**, app ID
**6819392473**, bundle **dev.dsmack.provider**, **build 2**, internal group **Lab**.
It was installed and exercised on an iPhone XS/iOS 18.5. This establishes an iOS
upload/install path, not the current App Store Connect state, external approval,
macOS availability, or an iOS 27 network run.

- [ ] Query the existing app record/build/group status using the existing account.
- [ ] Reuse its iOS record for the node if the product/bundle identity remains suitable;
      choose a new monotonically increasing build number from live state.
- [x] Generate the node's iOS Xcode project with the existing lab icon and create
      an unsigned device archive on Xcode 27. See the commands below.
- [ ] Sign/export the device archive, finish beta description, review
      contact/instructions and accurate encryption declaration.
- [ ] Add a macOS platform/version to the record if supported and desired; do not
      assume the iOS TestFlight build supplies a Mac build. Mac Store signing and
      sandbox requirements are a separate distribution configuration.
- [ ] Internal install and capture first; external group/review/public link next.
- [ ] Match the **installed** Apple-distributed executable/CDHash and evidence
      profile, not only the upload. Store processing can change the signature.
- [ ] Verify on iOS 27 hardware. Yesterday's XS cannot validate the authenticated
      code measurement required by this admission policy.

The older plan's “no TestFlight” constraint is superseded by Andrew's October 6
instruction. iPhone participation is foreground-only for the first release.

The authorized prior Claude session confirms yesterday's successful upload used
Xcode's saved account session with `-allowProvisioningUpdates`, `app-store-connect`
export and `destination=upload`. An API key is not required to reuse that local
path. Automated fork CI still needs each fork owner's own credentials.

Prepare the peer project and check its unsigned device archive:

```sh
python3 scripts/release/make_node_project.py
xcodebuild -project node/ios/AttestNode.xcodeproj -scheme AttestNode \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-dd -archivePath build/AttestNode-unsigned.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

The checked-in project is generated deterministically. It targets iOS 27, contains
the shared peer code and existing SwiftUI shell, and currently still requires
configuration input. It is not ready for external testing until the user flow and
network endpoint are implemented. Version/build defaults are placeholders; query
live App Store Connect state before assigning the upload build number.

Measured evidence is in `reproducibility-20261006.json`,
`payload-verification-20261006.json`, and `appattest-verification-20261006.json`.
`developer-id-appattest-20261006.json` records the separate Developer ID capture.
Full private development packages remain on the mini and are not public artifacts.

Current validation: 70 Python tests passed; 34 preexisting contract tests plus
three new Developer ID tests passed. Generated iOS project regeneration is
byte-identical. No hosted CI job, external TestFlight submission, persistent
zero-setup participant, or public release has been completed by this branch.

Release work is isolated on `release/mac-distribution`; the active visualization
checkout is untouched. The GitHub destination and final faucet meaning are pending
Andrew's answers. The suggested faucet is the existing shared testnet signing key,
with a verified exchange receipt; its all-holders-restart recovery remains a gate.

## Primary references

- [GitHub Xcode 27 hosted ARM64 image](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/)
- [GitHub Apple signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Apple adding platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)
- [Bitcoin Core reproducible builds and separate signing](https://github.com/bitcoin/bitcoin/blob/master/contrib/guix/README.md)
- [Recorded TestFlight experiment](../data/iphone-20261005-xs18/RESULTS.md)
- [Recorded peer network run](../data/p2p-run-20261006/RESULTS.md)
