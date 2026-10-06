# Apple p2p network: build plan (2026-10-05)

Goal: iPhone (iOS 27) + Mac mini (macOS 27) run one open-source node app; a Base Sepolia contract admits a node by the Apple-signed CDHash in App Attest, looked up in a CodeDirectory registry that any team may register re-signed copies in. Nodes then talk to each other directly. Inputs: `notes/apple-p2p-network-gap-inventory-2026-10-05.md`, `notes/ios-pre27-cdhash-infeasibility-2026-10-05.md`, code under `ios-app-attest/`. Facts below marked "measured today" were decoded from `iphone-20260923/captures/papi-20260923-snapshot.sqlite` and `solidity/fixtures/*.json` while writing this.

Constraints honored: no second Apple account; no TestFlight/App Store; DemoV1 keeps its admin; deployer `0x97883cb4` (`~/.foundry/keystores/deployer-new.key`; `tee-bridge/.env PRIVATE_KEY` is the same account); errors propagate, no fallbacks.

Coordination: another session is editing `ios-app-attest/` today. Steps 1–4 edit `ios-app-attest/solidity/`; start them after that session is done. All other new code lives in new dirs `ios-app-attest/node/` and `ios-app-attest/network/`.

## 1. What the network minimally is

**Nodes.** Three processes, two device classes: iPhone (ad hoc build, validation category 5), Mac mini process A (Apple Development build, category 3), Mac mini process B running a *re-signed copy* of the same Mac build (`codesign --force`, same identity; datasize changes, so a new CDHash — fixture I shows this). B is the live "interchangeable signer" demonstration we can run without a second account: a different CDHash admitted because the registry says it is the same code.

**Chain (Base Sepolia).** One `DemoV1` (the tee-interop `contracts/demo/DemoV1.sol` ABI, `TEE_INTEROP_DEMO_V1`, 11-word Request, which the Swift client already matches; `experiment-workspace`'s newer epoch/appKey ABI is not used) with two categories, `apple-ios` and `apple-macos`, both `overallEligible`. Each category has an adapter `AppleAttestRegistryV1` (Apple chain + CDHash per assertion, as `MacAppAttestV1` does today) that reads a per-class `CDRegistry`. The chain does three things: admit (every `execute` carries a fresh Apple assertion over the request context), commit each member's ephemeral P-256 session key (`Checked.sessionKeyHash`), and commit each group-key release (`KeyReceipt`). It never sees plaintext.

**Direct transport.** LAN TCP via Network.framework, Bonjour `_edgetee._tcp`, newline-delimited JSON. Three messages: `HELLO{member, joinTx, sessionPublic}` → `PARCEL{parcel, receiptTx}` → `PROOF{sig_groupKey(helloNonce)}`. The parcel is the existing 254-byte ECDH+HKDF+AES-GCM envelope from `macos/demo/main.swift`; the sender's `export` and receiver's `import` logic is reused unchanged. The group key is held in RAM only (custody result).

**Relay.** Devices hold no wallet. A Flask process on the laptop (`network/relay.py`, built on `demo-integration/control.py:execute`) signs `memberSignature` with `0x97883cb4` as `owner`, submits `execute`, returns the tx hash. It is a gas sponsor: it sees request + assertion + ciphertext digest. Both devices POST to it over LAN HTTP.

**What a node proves to a peer.** "A `Checked` event ≤60 s old names an active member of an Apple category, and its `sessionKeyHash` is keccak of the P-256 key I am talking to." Since `Checked` is only emitted after the adapter verified an Apple-rooted assertion whose CDHash is in the registry, the peer learns: genuine Apple device, admitted code running *now*, this session key. Peers read this over HTTPS RPC (`Chain.swift`), no light client, as today. One on-chain assertion per handshake (~0.27M gas).

## 2. Steps

Each: files, acceptance, [H] where Andrew's hands or devices are needed. `ssh mini-mesh` runs unattended; keychain unlock and Xcode account are the [H] gates on the Mac.

### 1. `AppleAuthData`: iOS profile
iPhone authData (measured today): flags `0xc0`, production AAGUID, 4-entry map: `apple_cd_hash_hash_01` (32 B bytes), `apple_cd_hash_type_01` (`0x02`), `apple_bundle_version_01` (**text string** `"1"`), `apple_validation_category_01` (`05000000`). Mac emits 3 entries, no bundle version. Current code requires exactly 3 byte-string entries.
- Files: `solidity/src/AppleAuthData.sol`. `check` accepts 3 or 4 entries; `apple_bundle_version_01` is text (major 3), value unchecked (the CDHash covers Info.plist); unknown or duplicate keys still revert. `check` returns `(counter, kid, cdhash, rp)` instead of taking `cdhash`/`appHash`; callers decide.
- Fixture: `solidity/fixtures/iphone-apple.json` exported from the snapshot: row 10 (key E honest enrollment: cert, auth, clientData = the 32-byte challenge nonce, kid, aaguid, cdhash `5395bf39…`, appHash `90a07dc6…`), rows 11/12 assertion authData (their clientData is a JSON blob, not 32 bytes, so they are parse-only fixtures; see step 9). Exporter: `scripts/export_fixture.py` (sqlite → JSON; reuses `verifier.core.decode`).
- Accept: new `test/AppleAuthData.t.sol`: Mac fresh fixture parses; iPhone row 10/11 parse with cdhash `5395…` and rp `90a07dc6…`; row 12 parses with cdhash `85678f…`; a 5th unknown key reverts; bundle version as bytes reverts. Existing `MacAppAttestV1.t.sol` 10/10 still pass.

### 2. `AppleLeaf`: ACL per device class
iPhone leaf (measured today): same CA 1 issuer, same EKU, same nonce format; OID 8.6 = `3049a3470445…` decoding to `{okd, oa, osgn, odel, ock}` all TRUE, vs the Mac's `{ok, oa, odel, osgn:[rsec, 1]}`; extra non-critical OIDs 8.5 and 8.7 (already tolerated).
- Files: `solidity/src/AppleLeaf.sol`: `parse(cert, issuerHash, nonce, aclHash)`; the Mac constant moves to the caller.
- Accept: `test/AppleLeaf.t.sol`: iPhone leaf at `vm.warp(1790200000)` passes with keccak of the iOS ACL bytes, reverts `"Mac ACL"`→ rename to `"key ACL"` with the Mac hash; Mac fixture unchanged.

### 3. `CDRegistry` v2: RP ID per build + header pin
- Files: `solidity/src/CDRegistry.sol`.
  - Record `rpIdHash[cdhash] = sha256(teamID ‖ "." ‖ identifier)` from `identOffset` (hdr 0x14) and `teamOffset` (hdr 0x30), NUL-terminated. Ad hoc CDs have `teamOffset == 0` → revert `"no team"` (they cannot App Attest anyway). For our App ID this equals the observed rp `90a07dc6…` (checked today: `sha256("DC9JH5DRMY.dev.dsmack.provider")`). Caveat recorded in the file: App ID prefix == team ID is assumed; true for this team.
  - Pin header fields that a re-signer controls: `keccak(cd[0x08:0x10] ‖ cd[0x24:0x28] ‖ cd[0x40:hdrEnd])` (version, flags incl. hardened-runtime bit, hashSize/type/platform/pageSize, execSeg*, runtime when version ≥0x20500; hdrEnd 0x58 or 0x60 by version) equals the approved value; `nSpecialSlots` and special slot −1 (Info.plist) equal the approved. Slots −2/−3/−5/−7 stay free (signer-dependent). `isAdmitted` stays.
  - Constructor args come from `scripts/cd_args.py <signed Mach-O>` (uses `macho_pages.cd_of` + the `mask()` scan from `cross_signer.py`) → JSON `{rest, maskedPage0, header, infoSlot, codeLimit, linkeditCmd, codeSigCmd}`.
- Fixtures: pull the Darkbloom cross-team pair from `mini-mesh:~/agent-drop/cd-crossteam-20261005/` and extract `.cd/.page0` → `fixtures/resign/darkbloom-eigen.*`, `darkbloom-ours.*` (5,384 slots, ~172 KB CD). Real two-team data: Developer ID (Eigen, SLDQ2GJ6TL) and Apple Development (ours).
- Accept: `CDRegistry.t.sol`: A–I admitted, M rejected (unchanged); flags bit flipped → `"header"`; Info.plist slot changed → `"info"`; `rpIdHash` for A = `90a07dc6…`; Darkbloom registry with Eigen approved admits both, `rpIdHash` differ and equal `sha256("SLDQ2GJ6TL.<ident>")` / `sha256("DC9JH5DRMY.<ident>")`; gas logged (expect ≈7.5M for Darkbloom).

### 4. `AppleAttestRegistryV1` adapter (multi-team in code)
- Files: new `solidity/src/AppleAttestRegistryV1.sol` = `MacAppAttestV1` with immutables `(registry, CDRegistry cds, aaguid, category, aclHash)`; no `appHash`, no `approvedCDHash`. On enroll and on every verify: `(count, kid, cdhash, rp) = AppleAuthData.check(...)`; `require(cds.rpIdHash(cdhash) == rp && rp != 0, "build not admitted")`. `MacAppAttestV1.sol` stays as archival. `IAdmissionV1.verify` unchanged.
- Accept: `test/AppleAttestRegistryV1.t.sol`:
  - Mac fresh fixture through a registry with A registered: enroll + `assert` accepted, `modified` → `"build not admitted"`, `restored` accepted, counter 3.
  - A re-signed build with a different CDHash (fixture I) has no Apple assertion in the repo, so that path is exercised live in step 9(b), not here.
  - iPhone row 10 enrolls on an iOS-profile adapter (category 5, iOS ACL) with its CD registered; the same bytes on the Mac-profile adapter revert `"key ACL"`; with the iOS CD unregistered revert `"build not admitted"`.
  - Multi-team unit: synthetic CD with teamID `ZZZZZZZZZZ` and the approved pages registers; `rpIdHash` = `sha256("ZZZZZZZZZZ.dev.dsmack.provider")`; `AppleAuthData.check` on an auth whose rp is that value, cdhash that CD's hash, passes the adapter's lookup (library-level, no Apple signature needed). This is the code path a second team would use.

### 5. Deploy script + local integration
- Files: copy tee-interop `contracts/demo/{DemoV1,DemoAssetsV1,IAdmissionV1}.sol` into `solidity/src/application/` with a `PIN.md` (source SHA-256); `foundry.toml` remapping to `experiment-workspace/contracts/application/vendor/openzeppelin-contracts-4.9.6/`. New `solidity/script/Network.s.sol`: deploy `CDRegistry` ×2 from `network/cd-args-{ios,macos}.json`, `registerBuild` for each approved build, `AppleAttestRegistryV1` ×2, `DemoV1(admin = deployer)`, `addCategory("apple-ios"|"apple-macos", policy = keccak(cdRegistry addr), adapter, true)`, enable both, unpause. Writes `network/deploy-<chain>.json` (addresses, ABI artifact paths).
- Accept: `test/Network.t.sol` runs the script's `run()` on a forked-free local chain with `P256Verifier` etched at `0x100`, then `vm.prank(registry)` → iOS adapter accepts iPhone row 10 enroll, Mac adapter accepts the Mac fixture verify. Then [H] Base Sepolia: `forge script … --keystore ~/.foundry/keystores/deployer-new.key --broadcast` (password prompt). Expect ~3 × ≤1M (small binaries) + deployments.

### 6. Shared node code (Swift) + Mac CLI
- Files: `node/Node.swift` (from `macos/demo/main.swift`: enroll on launch, `operation()` for join/bootstrap/export/import, RAM-only `held`), `node/Peer.swift` (NWListener + NWBrowser for `_edgetee._tcp`, JSON lines, HELLO/PARCEL/PROOF state machine calling `operation`), `node/Relay.swift` (POST response JSON to `<relay>/execute`, read `{tx}`), `node/Protocol.swift`, `node/Chain.swift` (registry address from Info.plist key `NetworkRegistry` instead of the constant). `node/mac/main.swift`: `node <relayURL> listen|connect`. `node/mac/build.sh` = `macos/demo/build.sh` with the new sources and `-D MODIFIED` variant kept.
- Accept: on the mini, [H] unlock the dsmack keychain, then unattended: build honest; process A `listen` → enroll → join → bootstrap overall (through the relay, on Base Sepolia); process B (same binary, second process) `connect` → join → HELLO → A exports → B imports → PROOF verified by A against `sharedKeys(scope)`. Responses + receipts saved under `network/evidence-<date>/mac/`.

### 7. Relay
- Files: `network/relay.py` (Flask; `--deploy network/deploy-base-sepolia.json`; `/health`, `/execute`). Reuses `control.execute` generalized to take registry address + artifact from the deploy file (edit `demo-integration/control.py` to drop the hard-coded `REGISTRY`/tee-interop artifact path; `client()` already reads `PRIVATE_KEY` = `0x97883cb4`). Reverts are returned as HTTP 500 with the revert string; nothing retried.
- Accept: `curl` a saved Mac `response-N.json` → mined tx; a response with one context bit flipped → 500 containing `assertion signature`.

### 8. iOS node app
- Files: `node/ios/` Xcode project (generate with a copy of `scripts/make_project.py`): bundle `dev.dsmack.provider` (same App ID as the Mac build, so the existing ad hoc profile `7a691543…` and App Attest Opt-In capability apply; no portal changes), entitlements = `app/AppAttestLab.entitlements` with environment `production`, Info.plist adds `NSLocalNetworkUsageDescription`, `NSBonjourServices [_edgetee._tcp]`, `NSAppTransportSecurity.NSAllowsLocalNetworking`, `NetworkRegistry`. `node/ios/NodeApp.swift`: SwiftUI with relay URL field, buttons Join / Connect / Listen, a log view; everything else from `node/*.swift`. `node/ios/build_adhoc.sh` from `scripts/build_adhoc.sh` (archive + export `release-testing`, automatic signing, cloud-managed Apple Distribution), honest and modified variants.
- [H] before building: confirm the available iPhone's UDID is among the profile's 18 devices (`scripts/profile_summary.py`); if not, add it in the portal and re-export (24–72 h per RESULTS.md). [H] Xcode account session on the mini for `-allowProvisioningUpdates`.
- After the honest IPA exists: `cd_args.py` on its main executable → `network/cd-args-ios.json`; this is what step 5 deploys/registers, so step 5's Base Sepolia broadcast happens after this build (local anvil test can use the 09-23 IPA's CD).
- Install [H]: serve `install/render.sh` output or `xcrun devicectl device install app` over USB; tap the Local Network prompt; keep the app foregrounded.
- Accept: app launches, `isSupported`, enrollment CBOR produced, Join through the relay → `Checked` event with category `apple-ios`.

### 9. Live network run and evidence [H]
Phone, mini and laptop on one LAN. Script `network/run.py` drives the Mac processes (`mac_ipc.py` pattern) and records everything; the phone is driven by taps.
1. Mac A listen + bootstrap overall; phone Join, Connect → HELLO → A validates `checkedPeer(joinTx)` + session binding → export (KeyReceipt tx) → PARCEL → phone imports → PROOF; A verifies.
2. Negative controls:
   (a) install the **modified** iOS build over the honest one (key survives, as rows 5/12 showed), Join → relay returns revert `build not admitted`;
   (b) Mac process B on the **re-signed copy** (`codesign --force`, variant-I style): Join → `build not admitted`; then `registerBuild(B's CD, page0)` (admin or anyone; ~0.1M gas) → Join accepted, same category, different CDHash — admission by code, not by signature bytes;
   (c) stale check-in: hold a HELLO >60 s → peer refuses `stale peer check-in`;
   (d) replay a PARCEL to a restarted phone process → `transport decryption` / `missing release commitment`.
3. Export the phone's first assertion over a 32-byte context (honest) and the modified-build attempt into `fixtures/iphone-node.json`; extend `AppleAttestRegistryV1.t.sol` with the on-chain iOS verify path (accept honest, revert modified). Until this run, the iOS *assertion* path is tested only live (the 09-23 assertions have JSON clientData and cannot be fed to `verify(bytes32)`).
4. Write `network/RESULTS.md`: table of actions × device × tx × verdict, CDHashes, registry entries, what was and was not tested (per lessons: "we tested only X").

### 10. Entitlement key-set pin (last; cut first if time runs out)
A re-signer can still ship the approved pages with `get-task-allow` or a different entitlement set (Fable review §1). Port `signer_neutral.check_entitlements` to `registerBuild(cd, page0, entDer)`: `sha256(entDer) == slot −7`; strict DER walk (`StrictDER`) of `SET OF SEQUENCE{UTF8String key, value}`; key list equals the approved list exactly; `application-identifier`/`team-identifier`/`keychain-access-groups` values must start with the CD's teamID; `app-attest-opt-in == ["CDhash"]`; `appattest-environment == "production"`; `get-task-allow` absent or false. Accept: Mac A/I and iOS honest entitlement DERs admitted; a DER with `get-task-allow=true` rejected; one with an extra key rejected.

Rough effort: steps 1–5 ≈ 2.5 days, 6–8 ≈ 2.5 days, 9 ≈ 0.5 day plus gates, 10 ≈ 0.75 day.

## 3. Cut

- Second Apple team capture, Developer ID signing, TestFlight/App Store CD retrieval (gap inventory Q1–Q3). Interchangeability is in code (steps 3–4) and demonstrated with the Darkbloom fixtures + the re-signed Mac copy.
- Off-chain peer verification of Apple evidence (device-side Apple chain verifier). The chain is the verifier; peers read it.
- Light client / RPC trust, gossip, more than one hop, NAT traversal, iOS background execution (phone is a foreground node).
- Sybil / per-device dedup, fraud receipts, Apple account encumbrance.
- Owner renounce or upgradeability changes; canary/`provideBug`; faucet/NFT claim (DemoV1 still has Claim; not exercised).
- `MacAppAttestV1` rewrite (kept archival), Python verifier changes (unchanged; `replay.py` still green).

## 4. Risks that could stall a step

- Leaf certificates expire ~2 days after enrollment (iPhone: 09-23 → 09-25); `verify` requires `block.timestamp <= expires`. Nodes re-enroll on launch (already the behavior), so a run must finish within the window; it does.
- `anvil` has no RIP-7212 at `0x100`; local tests etch `test/P256Verifier.sol`, the live chain is native (worked 2026-09-16).
- Bonjour between iPhone and Mac requires the same Wi‑Fi/LAN segment and the Local Network permission; the relay must be reachable from the phone (laptop IP on that LAN).
- Every node launch mints a new App Attest key → new member ID (accepted; Sybil is cut).
- The RP ID derivation assumes App ID prefix == team ID; true for `DC9JH5DRMY`, documented as an assumption in `CDRegistry.sol`.

## Amendment 2026-10-05 — remove human gates (Andrew)
- No keystore password: broadcast with PRIVATE_KEY (0x97883cb4) from /home/amiller/projects/dstack/tee-bridge/.env.
- No Bonjour / LAN: peers exchange HELLO/PARCEL/PROOF through the laptop relay over HTTPS (relay is untrusted transport; parcels are already sealed). Avoids the iOS Local Network prompt.
- Signing on mini: use the dedicated dsmack.keychain non-interactively from the build script; ask Andrew only if that actually fails.
- iOS 27 phone (00008140-…) is NOT paired with the mini (only the XS is), so its install stays an OTA tap. Batch it into a single install at the end.
- CORRECTION: Andrew has NO iOS 27 iPhone (the 09-23 capture was on papi's phone). Live network = Mac nodes on the mini (macOS 27) only; iOS is covered by on-chain replay of the 09-23 captures (fork 188ebc6). Drop iOS client/install steps.
- REVISED: keep the iOS client (thin SwiftUI shell over the shared node/ code). Test it in the iOS simulator against anvil + relay; App Attest is unsupported in the simulator, so the iOS attestation path is covered by (a) the same Swift attestation code running live on the macOS 27 mini and (b) on-chain replay of papi's 09-23 iPhone captures. Final real-device check = a friend's iOS 27 iPhone via ad hoc OTA install (needs their UDID in the profile), once, at the end.
