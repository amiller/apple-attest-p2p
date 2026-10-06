# Before iOS 27, App Attest cannot make developers interchangeable (2026-10-05)

Question: on iOS versions before 27, could a verifier that trusts Apple but not the developer admit an exact program, so that any developer account could run an approved build and none could slip in another? And if Apple's evidence can't do it, what does an encumbered developer account (the pi-fido experiment) buy instead?

Short answer: no. Before 27, Apple-signed App Attest evidence names the App ID (team ID + bundle ID), the device and the key, but not the code. 18.5 through 26.x do attach a CDHash, but it is added after everything is signed, so the app can rewrite it. Admission therefore means trusting whoever controls the signing account. Encumbering that account could in principle stand in for code evidence on old iOS. It relies on an unattestable setup ceremony, an untested Apple account state (gate 2), one encumbered account per operator, and Apple's own re-signing. The verifier would still see no code evidence in any assertion.

## What is tested vs inferred

| iOS | What happens to the CDHash | Evidence class | Source |
|---|---|---|---|
| 14.0–18.4 | Absent. The opt-in and CDHash strings do not exist in `AppAttestInternal` | Apple binary strings (third-party ipsw-diffs); no capture | `notes/appattest-cdhash-timeline-2026-10-05.md` |
| 18.5 (22F75) | Top-level `cdHash` map, 20 bytes, outside authData, outside the nonce and the assertion signature | **Captured**, iPhone XS, TestFlight build | `ios-app-attest/iphone-20261005-xs18/RESULTS.md` |
| 18.5 (22F76) | Same placement: inserted after authData is finished and after the assertion is signed | Apple binary, disassembled | `notes/appattest-cdhash-re-2026-10-05.md` |
| 18.6–26.4 | Assumed same as 18.5 | **Inferred**: no CDHash string added or removed in any ipsw diff in this range. The 26.1 and 26.4 CBOR refactors could have moved it without changing a string | timeline note, "string continuity" |
| 26.5 (23F77) | Same as 18.5, in both the ObjC path and the new Swift CBOR managers | Apple binary, disassembled; no capture | RE note |
| 27.0 (24A437) | `apple_cd_hash_hash_01` / `_type_01` appended to authData extensions, flag 0x80 set, then hashed and signed | Apple binary, disassembled | RE note |
| 27.2 beta (24B5089g) | Same, 32 bytes, in enrollment and every assertion; substitution visible both ways | **Captured**, one iPhone, ad hoc build | `ios-app-attest/iphone-20260923/RESULTS.md`; build from leaf OID 1.2.840.113635.100.8.7 per `notes/fable-review-appattest-2026-10-05.md` |
| macOS 27.0 (26A428) | Same as iOS 27 | **Captured**, Mac mini | `ios-app-attest/macos/RESULTS.md` |

When things were introduced, per Apple binaries (ipsw-diffs): the opt-in machinery (`AppAttestCDHash`, `_fetchCdHash`, `addCdHash`) appears in iOS 18.5 beta 1 (22F5042g, April 2025). The entitlement string `com.apple.developer.devicecheck.app-attest-opt-in` with value `CDhash` appears in 18.5 beta 2 (22F5053f). The signed extension names appear in 27.0 beta 1 (24A5355q, 8 June 2026), and the same diff removes the 18.5 top-level code. Apple's documentation says neither. As of 2026-10-05 the entitlement page does not exist, and "Validating apps that connect to your server" lists the category and bundle-version extensions but not `apple_cd_hash_*`. WWDC26 session 201 says authData extensions are "new in iOS 27" without naming the hash (`ios-app-attest/iphone-20260923/DOCS.md`, timeline note). No new web search was run for this note; the timeline note's fetches are from today.

Not tested on hardware: anything from 14.0 to 18.4, 18.6–26.x, iOS 26 in general, iPadOS. 22F75 (captured) and 22F76 (disassembled) are assumed to be the same code. The 18.5 capture's 20 bytes were never matched against the installed binary, because Apple re-signs TestFlight builds and the installed executable was not retrieved.

## 1. What a verifier can bind before 27

From the attestation and assertions (`docs/AUTH-GATE-MAP.md`, Apple's validation guide):

- **App ID.** `rpIdHash = SHA256(teamID.bundleID)`. That is the only app binding.
- **Device genuineness.** The leaf certificate chains to the Apple App Attest Root CA, and the nonce extension binds authData and the challenge. The aaguid separates development from production. Leaf OIDs give the OS version (8.7).
- **Key continuity.** The credential ID is the hash of the attested public key, and assertions carry a counter.
- **Receipt.** Feeds Apple's fraud metric (a count of keys per device). It says nothing about code.

None of these change when different code runs under the same App ID. The 27 iPhone run shows that an App Attest key survives an in-place install of different code (rows 5 and 12), and the macOS run shows the same with key A. On 27 the next assertion reports the new hash. Before 27 nothing in the signed data changes, so the verifier cannot tell an evil twin's assertion from the honest build's.

The verifier's policy therefore reduces to "any build signed under `teamID.bundleID`". Whoever can get a certificate and provisioning profile for that App ID decides what runs. On the test team that is anyone holding a portal session: certificate creation needs no re-authentication (`docs/AUTH-GATE-MAP.md`). It is also anyone using Xcode's cloud-managed distribution certificate, which signed the 09-23 builds, and any Account Holder or Admin of an organization team. Developers are not interchangeable here: each team's admission is exactly as good as trust in that team. `docs/CUSTODY.md` says the same: an app's own claim about its hash, or a key embedded in the app, does not repair this.

## 2. Why the unsigned `cdHash` is worthless as evidence

On 18.5 the attestation object is `{fmt, cdHash, attStmt, authData}`. The certificate nonce equals `SHA256(authData || SHA256(challenge))` and does not include `cdHash`. The assertion is `{cdHash, signature, authenticatorData}`, and the signature covers `SHA256(authenticatorData || SHA256(clientData))`, again without `cdHash`. The disassembly shows why: `_generateAttestationObject` and `_generateAssertionObject` add the `cdHash` key to the outer CBOR map after authData is finished and after `SecKeyCreateSignature` has run.

The object passes through the app on its way to the verifier. The app is the code being measured. A modified build can replace the 20 bytes with the approved build's value, and every signature and chain check still passes. The field therefore can't tell the honest build from the modified one, which is the one thing it was needed for. It also holds only 20 bytes (the kernel's `CS_OPS_CDHASH_WITH_INFO` struct), not the full SHA-256. Who the field was meant for is not known, and this note does not guess.

## 3. What an encumbered account buys on old iOS

Idea: if no human can sign code under the App ID, then "signed under `teamID.bundleID`" means "approved code". A TEE holds every credential that can obtain a certificate or upload a build. It signs or uploads only builds that match an approved, reproducibly built artifact. This doesn't need the CDHash fields, so in principle it works on any iOS that has App Attest (14.0+).

What has been shown (`ios-app-attest/pi-fido/`, `evidence-20260924/`):

- **Gate 1 passed.** A Raspberry Pi presented as a USB HID CTAP2 authenticator (`authenticator.py`, AAGUID `edge-tee-pi-fido`, automatic user presence) was enrolled as a security key on the real Apple ID via System Settings on the Mac mini. Apple ID sign-in then completed with no human touch (logs `log-apple-batch-and-signin.jsonl`, `log-apple-batch-retry.jsonl`). `fmt: none` was refused twice (`log-apple-none*.jsonl`). `packed` with a self-signed batch certificate not in FIDO MDS was accepted twice. So Apple appears to require some attestation statement but does not check FIDO certification. This contradicts the 09-04 web-research note that Apple accepts `none`.
- What gate 1 does **not** show: the key is plaintext on the Pi, not in a TEE, and the account still has two YubiKeys, the Mac mini as a trusted device and an SMS phone number. Nothing has been taken away from the human.

Costs, and why the construction is more contrived than checking a hash:

1. **An encumbered account per operator.** In an organization team, the Account Holder and Admins keep certificate authority over every bundle ID, so the plan is a separate Individual membership per encumbered App ID. That means $99 a year, identity verification with a real name and date of birth, and no team members (memory note "Apple account encumbrance"). Making developers interchangeable then means every operator repeats the whole ceremony, and the verifier trusts each ceremony separately. One shared encumbered account would instead be a single Apple account that every operator depends on.
2. **Setup that can't be attested.** Security-key enrollment works only from Settings on an already-trusted Apple device; there is no browser path (`docs/AUTH-GATE-MAP.md`). A human with a trusted device runs setup. No Apple API reports an account's factors, trusted devices or recovery configuration, so a verifier can't check afterwards that nothing was kept. The claim rests on witnesses to the ceremony.
3. **Gate 2 untested: Apple's escape hatches.** Apple says that with security keys on, standard account recovery is off, and losing all keys and trusted devices means permanent lockout (support 102637, 109345). Apple does not say an account may run with zero trusted devices. Its wording is "security key or trusted device", and it says nothing about removing the last trusted phone number. Until every trusted device and the phone are shed in a real test, any one of them is a standing human backdoor. Apple's account risk engine (silent enrollment bounces, account-creation throttling on 09-16) is undocumented and could block or reverse that state.
4. **Every other authority path has to be covered too.** That includes portal sessions, App Store Connect API keys, cloud-managed signing certificates, provisioning-profile and device-registration changes, and agreement acceptance and renewal, which the 09-04 research says needs an interactive web login several times a year (not tested here). `docs/CUSTODY.md` lists eleven obligations, all "Not established".
5. **Apple re-signs TestFlight and App Store builds.** The binary that runs is Apple's re-signed one, not the controller's upload. The 09-04 research also notes FairPlay encryption of App Store `__TEXT` (not tested here). The controller can only gate what it uploads, so "approved code" depends on Apple's signing step as well. Ad hoc avoids re-signing but caps each team at 100 registered devices per membership year, and the encumbered account must register every UDID itself.
6. **No per-assertion code evidence.** Even if everything above holds, each assertion still says only `teamID.bundleID`. App Attest keys survive code changes (shown on 27; the key lifecycle is assumed to be the same before 27). So if the encumbrance ever breaks, for example a second certificate minted between watchdog polls (`docs/CUSTODY.md`), substituted builds keep producing assertions that look exactly like honest ones. Past and future evidence can't show it. On 27 the substitution shows up in the next assertion.

Encumbrance therefore changes the trust assumption from "trust the developer" to "trust that a one-time ceremony removed the developer, that Apple's account policy works as written and stays that way, and that this was done once per operator". Section 2 shows that 18.5–26.x add nothing a verifier can use.

## 4. Open gaps

- **18.6–26.x on hardware.** The unsigned placement there is inferred from string continuity plus the 26.5 disassembly; which 26.5 code path is live was not determined. An opt-in capture on any 26.x device would settle it.
- **22F75 vs 22F76** identity of `AppAttestInternal`: assumed.
- **Gate 2:** whether every trusted device and the phone number can be removed with only security keys left. Untested; blocks any encumbrance claim.
- **Pi key in a TEE.** The authenticator holds its key in plaintext on the Pi. Moving it into an enclave has not been attempted.
- **Second team on 27.** No App Attest capture from a second developer team exists. The cross-team re-signing data (Darkbloom under Eigen Labs vs our team: 5,383 of 5,384 page slots equal, page 0 differing only in three signature-size fields, `tasks/cd-registry-gas-2026-10-05.md`) is mechanics, not admission. Re-signed copies here were produced with Apple `codesign` (`local-resign-20261005/`, variants B–I) and checked by `scripts/cross_signer.py`.
- **`CDRegistry.sol` checks code pages only.** It does not pin entitlements or CodeDirectory flags, so a second team could register the approved pages re-signed with `get-task-allow` or without hardened runtime. The page-0 mask has no written security argument yet (Fable review §1, §3).
- **Opt-in availability.** Whether every team can turn on the App Attest Opt-In capability or must request it is unknown. If it is request-only, interchangeability on 27 covers only teams Apple approves.
- **27 SDK gating.** The disassembly suggests extensions are added only for apps linked against the 27 SDK, which fits Darkbloom's SDK 26.5 report. This was read from code, not tested.
- **Store builds.** Whether an App Store or TestFlight download yields a CodeDirectory a verifier can compute in advance is untested on any version.
- **Receipt.** The Apple-signed receipt was not examined for any code-related field. Apple documents none.
- **Device floor.** Requiring the 27 extension excludes devices that can't run 27 (iPhone XS and older).
