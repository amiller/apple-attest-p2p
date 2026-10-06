# Apple p2p network: gap inventory (2026-10-05)

Target: a network of Apple devices (iPhone on iOS 27+, Mac on macOS 27+ as a separate class) running one fixed open-source app. Any developer team may re-sign and ship the approved build. A node is admitted on the Apple-attested CDHash, not the team.

Read-only inventory of `ios-app-attest/` and `experiment-workspace/`. "Inference" marks claims not backed by a capture or test. Paths are relative to `edge-tee/`.

## (a) Components

| Component | Status | Evidence |
|---|---|---|
| Apple-signed CDHash in enrollment + every assertion, macOS 27 | exists, tested on hardware | `ios-app-attest/macos/RESULTS.md` (6-step matrix, key A reuse by modified code is rejected by CDHash policy) |
| Same, iOS 27 (iPhone, ad hoc, production env) | exists, tested on hardware | `ios-app-attest/iphone-20260923/RESULTS.md` rows 5/12. Leaf OID 8.7 reads iOS 27.2 build 24B5089g, "Beta" (decoded today from the snapshot's leaf cert) |
| iOS 18.5 negative control (cdHash outside signed data) | tested | `ios-app-attest/iphone-20261005-xs18/RESULTS.md` |
| Offline Python verifier with CDHash allowlist | exists, tested (51 py tests per README) | `ios-app-attest/verifier/core.py`. One `app_id` per policy, so one team per policy |
| Signer-neutral offline admission (code-equivalence + entitlement key-set pin) | exists, tested, same team only | `experiment-workspace/tools/data/apple/signer_neutral.py`, `macho_normalize.py`. Admitted `provider` vs `provider2` (same team, other bundle ID) |
| On-chain Apple verifier `MacAppAttestV1` | exists, tested (10 forge tests pass, re-run today, outputs redirected to scratch) | `ios-app-attest/solidity/src/MacAppAttestV1.sol`. Copy also in `experiment-workspace/contracts/` |
| `MacAppAttestV1` on iOS evidence | **missing, so iOS evidence is rejected** | It requires extension map count == 3, all values byte strings. iPhone authData has 4 entries (`a4`), with `apple_bundle_version_01` as a text string. Checked today on the snapshot. It also requires the exact Mac ACL bytes in OID 8.6. The iPhone 8.6 value differs (`3049a347…`, has an `ock` entry) |
| `MacAppAttestV1` multi-team | **missing** | `appHash` (RP ID hash) and `approvedCDHash` are single immutables. Does not read `CDRegistry` |
| `CDRegistry` (admit re-signed copies of one Mach-O via masked page 0) | exists, tested on Mac re-signs only | `ios-app-attest/solidity/src/CDRegistry.sol`, `test/CDRegistry.t.sol` (4 pass today). Fixtures A–I are the Mac probe re-signed by Apple `codesign`: ad hoc, or Apple Development of team DC9JH5DRMY. M-modified rejected. No iOS fixture, no second-team fixture in repo |
| Cross-team page equality (Eigen Labs Developer ID vs our Apple Development, Darkbloom) | measured, not in repo fixtures | `tasks/cd-registry-gas-2026-10-05.md` §"Cross-team": 5,383/5,384 slots equal, page-0 diffs inside the mask. Data on the mini `~/agent-drop/cd-crossteam-20261005/`. Script `ios-app-attest/scripts/cross_signer.py` |
| CDRegistry checks of CD flags, entitlements, Info.plist, resources | **missing** | Contract checks code slots + masked page 0 only. `notes/fable-review-appattest-2026-10-05.md` §1: a re-signer can add `get-task-allow` or drop hardened runtime. `signer_neutral.py` pinned the entitlement set; the port dropped it |
| Membership registry + adapter interface | exists, deployed once (Base Sepolia `0xCea3a2E7…`, Mac + dstack, 2026-09-16) | `experiment-workspace/contracts/application/DemoV1.sol`, `IAdmissionV1.sol`. One category per adapter instance (owner adds categories). Member ID = keccak(category, App Attest key ID) |
| Peer-to-peer protocol | **exists only as Mac↔dstack key transfer via chain** | `ios-app-attest/macos/demo/{main,Chain}.swift`. Peers authenticate each other by reading a `Checked(member, category, owner, context, sessionKeyHash)` event ≤60 s old over HTTPS RPC (no light client). Then ECDH(P-256) + HKDF + AES-GCM parcel, with `KeyReceipt` on chain. No direct device↔device transport, no gossip, no iOS client. Writeup: `experiment-workspace/attestation-browsers/mac-dstack-transfer/README.md` |
| Memory-only secret custody (vs Keychain) | tested on Mac | `ios-app-attest/macos/custody/RESULTS.md`: modified same-identity code reads the Keychain item. iOS custody untested |
| Second Apple team App Attest capture | **missing** | README matrix "Independent team B: not run". Same in Fable review §3 and task file ("Not done: an App Attest capture from our re-signed copy") |
| Store channels (TestFlight/App Store re-sign) CD match | **missing** | xs18 run used TestFlight but did not retrieve the installed binary |
| Developer ID (Mac category 6) capture by us | **missing** | Our captures: Development (Mac, category 3) and ad hoc (iPhone, category 5). `tasks/testnet-v2-plan-2026-10-05.md` §2 |
| Sybil / per-device dedup | **missing** | DemoV1 README: member ID "is not a physical-device uniqueness proof". Fraud receipts retained, not validated (`RESULTS.md`) |

## (b) Open questions that decide feasibility

1. **Does Apple's distribution re-signing stay inside CDRegistry's mask?**
   - Measured: Apple Development, ad hoc, and Developer ID (Eigen) re-signs change only `__LINKEDIT` vmsize/filesize and `LC_CODE_SIGNATURE` datasize. All are Mac executables.
   - Untested: TestFlight and App Store. For iOS beyond 100 ad hoc devices per team, this is the gate.
   - Inference, to check: store processing may change page-0 load commands outside the mask (e.g. `LC_ENCRYPTION_INFO_64` cryptid for FairPlay) or thin per device model. Either would break "pages 1..n equal + masked page 0" or multiply reference values.
   - Next step: retrieve an installed TestFlight binary.
2. **Has a second team's attestation ever been accepted under one CDHash policy?** No. Zero captures. Cross-team evidence so far is static page comparison of a Darkbloom binary. No App Attest run from a team-B signed build exists.
3. **Is the App Attest Opt-In capability self-serve for every team?** Unknown (Fable review §1, question two). If request-only, the set of developers is gated by Apple.
4. **What does the re-signer control that the registry does not pin?**
   - CD flags: hardened runtime, library validation.
   - Entitlements: `get-task-allow`, DYLD/library-validation exceptions on macOS.
   - Info.plist (slot -1).
   - Resources (slot -3), including embedded frameworks that the unchanged main binary loads.
   - Other executables in the bundle. Inference: App Attest reports the main executable's CD only (observed field is the "running main executable"). Darkbloom ships a second executable, `darkbloom-enclave`.
   - The fix is to pin flags and the entitlement set, and either forbid bundled code or pin the resource slot modulo signer. This is not designed.
5. **What does the on-chain verifier check per assertion?** `MacAppAttestV1.verify` checks:
   - caller == registry;
   - key enrolled, not past the leaf cert expiry, not past the CA 1 anchor expiry (1899590400);
   - RP ID hash == the single `appHash`, flags, exactly 3 extensions;
   - `apple_cd_hash_hash_01` == the single `approvedCDHash`, type 0x02, validation category;
   - counter > stored counter;
   - P-256 signature over sha256(auth ‖ sha256(context)) via precompile 0x100.

   Not checked:
   - Freshness. `context` comes from the caller; DemoV1 binds it to chainId/contract/request with a 60 s deadline and an owner nonce.
   - Enrollment challenge. `enroll` is permissionless with any clientData.
   - CA 1 → Apple root, which is checked offline only.

   Gas: enroll median ~6.5M, verify ~0.27M (`tasks/testnet-v2-plan-2026-10-05.md`).
6. **How do peers authenticate each other?**
   - Today, only through the chain. A peer accepts a counterparty if its `Checked` event is ≤60 s old, is in a canonical block per the RPC, names an active member, and commits `sessionKeyHash` to the presented ECDH key.
   - `memberSignature` authenticates the owner/relay wallet, not the device (mac-dstack-transfer README).
   - Every peer handshake costs one on-chain assertion (~0.27M gas). No off-chain assertion exchange between devices exists.
   - Trust in the RPC endpoint is explicit (`Chain.swift` comment).
7. **RP ID across teams.**
   - Each team's App ID gives a distinct RP ID hash.
   - CDRegistry stores only `isAdmitted[cdhash]`. It does not record the CD's identifier/teamID, so an adapter cannot cross-check RP ID against the admitted build.
   - Inference: the CD's identifier and teamID strings (offsets in `tasks/cd-registry-gas-2026-10-05.md` §1) let registration record the expected RP ID per CDHash. The App ID prefix vs team ID needs checking.
8. **Sybil and custody under many teams.**
   - One device can mint many App Attest keys. Each key becomes a distinct member.
   - Apple's fraud receipt is per team. Inference: no cross-team device dedup is available from Apple.
   - Any team can ship modified code under its own App ID and read that App ID's Keychain. So shared secrets must be memory-only and released only against a fresh assertion (tested on Mac only).
9. **iOS as a node.**
   - iOS evidence fails the current contract (see table).
   - No iOS p2p client exists.
   - Background execution limits for a long-lived node are untested. This is inference: an iPhone is likely a foreground or intermittent node.

## (c) Minimal build plan: 2 devices, 2 teams, 1 contract

Mac-first, since the Mac adapter exists and the testnet-v2 plan says Mac first. **[H]** = needs a human (Apple account, device, physical action).

1. **[H]** Get team B: the individual account (memory: "individual dev account decided") or Michio's team. Create an App ID with App Attest + App Attest Opt-In. This settles Q3.
2. Harden `CDRegistry`:
   - Pin CD flags/runtime and execSeg flags.
   - Pin the entitlement key set with team-derived values substituted (port from `signer_neutral.py`). Forbid `get-task-allow`.
   - Pin bundle structure (no extra executables or frameworks).
   - Record the expected RP ID hash per CDHash at registration.
   - Write the page-0 mask argument.
   - Add the Darkbloom cross-team CDs as fixtures.
3. New adapter `AppleAttestRegistryV1`:
   - `MacAppAttestV1` logic, but CDHash from `CDRegistry.isAdmitted` (enrollment and every assertion).
   - RP ID from the registry entry.
   - Category/AAGUID/ACL fixed per device class.

   Forge tests:
   - existing Mac fixtures accepted;
   - Mac key-A reuse by modified code rejected;
   - wrong RP ID for a CDHash rejected.
4. **[H, Mac]** Re-sign the approved Mac probe under team B on the mini. Apple Development is enough for the demo; Developer ID is a follow-up. Put team B's identity in the mini keychain. Capture enrollment + assertions + a team-B-signed modified build. This is the first second-team capture (Q2).
5. Register team A's and team B's CDs in `CDRegistry` on anvil. Replay both captures through the adapter. Team B modified must be rejected.
6. **[H, device]** Second Mac for node B (or decide that two processes on one Mac count as "two devices", which is weaker). Deploy registry + adapter + DemoV1 with one category on Base Sepolia, keeping an admin per testnet-v2.
7. Reuse `macos/demo` actions:
   - A `join`/`bootstrap`, B `join`.
   - B gets the group key from A via `export`/`import` (`Checked` + `KeyReceipt`).
   - Negative controls: team-B `get-task-allow` build, modified build, stale (>60 s) check-in, replayed assertion.
8. iOS class (separate, after 1–7):
   - **[H]** iOS 27 iPhone. papi's phone was borrowed; the testnet plan says there is no spare.
   - Add an iOS profile to the adapter: 4-entry map, text bundle version, decoded iOS 8.6, category 5 or store.
   - **[H]** Settle Q1 by pulling a TestFlight-installed binary before counting on store distribution.
