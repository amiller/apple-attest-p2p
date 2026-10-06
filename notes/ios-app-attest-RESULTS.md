# Execution record — 2026-09-09

**September 23 iPhone result:** [real iPhone results](iphone-20260923/RESULTS.md).
An ad hoc build with the CDHash opt-in gets the full CodeDirectory SHA-256 in
Apple-signed enrollment and every assertion on an iPhone (iOS 27.x). In-place
substitution was tested in both directions with a retained key: the approved-hash
policy rejects the modified build. This matches the macOS 27 result.

**September 16 custody follow-up:** [real Mac results](macos/custody/RESULTS.md)
confirm modified-code access to the tested persistent Keychain key and successful
memory-only crash/restart recovery after fresh attestation. Combined suite: 51
passing tests. This is a lab authority/receiver experiment, not contract integration.

**September 16 addition:** [macOS 27 substitution results](macos/RESULTS.md) now
include fully Apple-rooted enrollment, fresh assertions, modified-code key reuse,
and restored-code control. Both attestation and assertion CDHashes match the
respective binaries. 48 combined Python tests pass. The record below describes
the earlier September 9 iPhone sprint; physical iOS tests ran on September 23 (above).

## Result so far

As of September 9 the harness was implemented and locally tested, with no fresh
iPhone attestation. The September 23 session ([iphone-20260923](iphone-20260923/RESULTS.md))
supersedes the device rows below. Developer-independent interop membership has
not been demonstrated.

| Work | Evidence/status |
|---|---|
| Offline verifier | Implemented; pinned Apple root, bounded CBOR parsing, chain/nonce/key/RP/environment checks, assertion signature and counter checks |
| Challenge service | Implemented; key/purpose-bound expiring challenges, atomic consumption and durable counters in SQLite |
| Independent compatibility | Published enrollment fixture verifies under Apple's root at its historical validity time; published assertion verifies; expired enrollment rejected as current |
| Synthetic adversarial suite | 34 tests passed, including independent tests; synthetic evidence always labeled |
| iOS client | SwiftUI source and generated Xcode project ready; honest and modified operation variants; capture before send and export |
| Build assets | Manual-signing script, unsigned-build command, public-metadata manifest collector, inventory script |
| Xcode compilation | Both unsigned variants built successfully on the Mac with Xcode 26.6 (17F113), iOS SDK 26.5 |
| Mac verifier runtime | Isolated Python 3.9.6 venv installed; OpenSSL 3.6.4; independent historical fixture and health check pass |
| Simulator execution | Eight actual XCUITests pass (four per variant): unsupported DeviceCheck, trusted HTTPS, rejected untrusted TLS, rejected HTTP |
| Capture persistence | Separate session JSON survives app updates; honest output 4 and modified output 5 explicitly unattested |
| Native clean rebuild | Two 265,584-byte executables differ only at two embedded build-path bytes; unsigned full bundles are not byte-identical |
| Signed development builds | Both variants built and passed strict signature verification; actual signer/entitlements captured |
| Physical device installation | Done 2026-09-23: ad hoc builds installed over the air on one iPhone ([iphone-20260923](iphone-20260923/RESULTS.md)) |
| Real App Attest baseline A | Done 2026-09-23: enrollment and assertions, Apple-rooted, CDHash present ([iphone-20260923](iphone-20260923/RESULTS.md)) |
| Same-team second-credential test C | Not run |
| Independent team B | Inventory not confirmed; not run |
| Full signing/account custody | Closure obligations documented; no TEE signing service deployed and no account changes performed |
| Interop adapter | Deliberately gated on fixed-code/custody evidence; no member admitted |
| Fable | Clear task and success conditions in `docs/FABLE-TASK.md`; not dispatched, connection unknown |

## Validation performed

From this directory:

```text
python3 -m pytest -q
34 passed in 1.07s
```

Also checked Python compilation, shell syntax, plist parsing, scheme XML, and CLI
argument parsing. Subsequently compiled both variants using Xcode on the Mac.
The [build evidence](docs/build-evidence/README.md) records commands, logs and unsigned
binary hashes. Signed installation and device execution remain untested.

Independent tests caught a compatibility error during development: the assertion
fixture has AT=1 without attested-key data. The parser now handles the legacy
assertion layout by message type. The independent assertion also verifies the
ECDSA hashing convention, avoiding reliance solely on synthetic fixtures that
could reproduce the same implementation mistake.

## Evidence boundaries

An authenticated output 5 is intentionally recorded as identity acceptance with
`computation_matches: false`. `fixed_code_verified` stays false on every response.
The server authenticates app identity and requests, not a source hash. It neither
releases an interop secret nor maps client-provided code hashes to verified code IDs.

Fraud receipts are retained but **not independently validated**; no fraud-metric
claim is made. Unsupported CBOR/extension layouts are rejected and need investigation
against real captures. iOS 27 behavior is not a tested dependency of this harness.

Published historical vectors are clearly attributed in `tests/fixtures/README.md`.
They establish compatibility with those objects, not ownership of a real lab phone
or success of this sprint's attack. Historical certificate validation time is a
library fixture parameter and never accepted from HTTP requests.

## Simulator and build evidence

The repeatable `scripts/simulator_preflight.sh` completed on the Mac on September 9.
Both variants passed all four tests, with zero failures or skips. The real Apple
DeviceCheck API reports unsupported. The trusted HTTPS preflight succeeds; an
untrusted TLS certificate produces NSURLErrorDomain -1202. No attestation keys,
challenges, or evidence were created in either service database. See the saved
[summaries and app captures](docs/simulator-evidence/README.md).

Two clean Release iPhoneOS builds of the updated source compiled successfully.
The unsigned executables have the same UUID and length; only offsets 258145 and
265342 differ, each containing the `a` versus `b` in `device-preflight-a/b` build
paths. All other executable bytes and both other bundle files match. This is a
local reproducibility diagnostic, not a signed-build or source provenance proof.
Hashes are in [reproducibility.json](docs/build-evidence/reproducibility.json).

## Current blockers and exact next actions

1. Mac access works through `ssh mini` outside sandbox networking. The saved
   Remmina profile used a stale LAN address; it now uses a working loopback SSH
   tunnel at `127.0.0.1:5901`. The VNC handshake was verified. The tunnel lasts
   for this connection session, not across workstation reboots.
2. **Xcode account sign-in is resolved.** Automatic provisioning obtained
   `iOS Team Provisioning Profile: dev.dsmack.appattestsok`, valid until September 9,
   2027. It authorizes App Attest development/production, 18 registered devices,
   and 12 developer certificates, including the installed certificate. This does
   not establish possession of a second private key. Device identifiers are omitted
   from the [public summary](docs/build-evidence/ios-profile-summary.json).
   **Signing is resolved.** With the user's explicit authorization, the existing
   dsmack packaging configuration supplied its keychain password without placing
   it in process arguments. Unlock and signing ran in the same SSH security session,
   with the keychain selected explicitly. Both builds now pass strict verification.
   The Xcode-managed profile requires explicitly selecting automatic signing;
   no provisioning updates were enabled in these successful builds.
3. When the phone is available, pair it, enable development, and confirm the existing
   iOS App Attest profile includes that phone. Follow [PHONE-SESSION.md](docs/PHONE-SESSION.md) for the
   HTTPS setup, baseline, update, alternate-credential and distribution comparisons.
4. Full account custody and a second independent team remain separate gates for
   the stronger claim. The Fable handoff is specified but has not been dispatched.

## Additional unsigned reproducibility diagnostic

Applied `xcrun strip -S` separately to copies of the two clean native executables.
The resulting SHA-256 values match:
`6389eef559e6e8b75f47e0ccc2f07391d5e2b998e10da47cb2ccd1177d3673c1`.
Original build outputs were preserved. This confirms the observed debug-path
difference can be removed; it does not prove independent-toolchain reproduction,
signed artifact reproducibility, or encumbered build/sign custody.

## Signed baseline artifacts

The [signed comparison](docs/build-evidence/signed-comparison.json) confirms different
executable hashes with identical App ID, version 1, development App Attest entitlement,
and actual signing certificate. Both have `get-task-allow=true`; these are development
controls. Public certificate chains and per-file hashes are preserved in the two
`signed-*-manifest.json` files. Signed bundles and logs remain on the Mac under
`captures/signed-ready-20260909-honest` and `captures/signed-ready-20260909-modified`.
The certificate extraction collector was corrected to use codesign's
`--extract-certificates=PREFIX` syntax and exercised successfully on both real apps.

Physical installation, fresh App Attest issuance, second-private-key substitution,
and distribution controls remain untested. No fixed-code membership is claimed.
