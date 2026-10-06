# apple-attest-p2p

Admission for a permissionless peer-to-peer network of iPhones and Macs, using App Attest on iOS/macOS 27. On those versions the App Attest attestation and assertions carry the running app's CDHash, so a contract can admit a device only if it runs a registered build. Copied out of `edge-tee/ios-app-attest` on 2026-10-06.

Layout:
- `contracts/` Foundry project: `CDRegistry` (CDHash -> build), `AppleAttestRegistryV1` / `MacAppAttestV1` adapters, P-384 and DER parsing, deploy script (`script/Network.s.sol`, outputs in `network/`). forge-std and OpenZeppelin 4.9.6 are vendored in `lib/`.
- `verifier/`, `tests/`, `trust/`, `scripts/` Python App Attest verifier, its tests, the pinned Apple root, and build/inspection scripts (`cd_layout.py`, `cross_signer.py`, `macho_pages.py`).
- `app/` probe iOS app source; `app/macos/` macOS probe, demo (`demo/Chain.swift`), custody experiment and evidence.
- `data/` iPhone captures (iOS 27, 2026-09-23; iOS 18.5 XS, 2026-10-05), local re-signing matrix, explainer inputs (`data/ios`).
- `explainer/` single-page explainer, built from `template.html` + `data/ios`.
- `node/` empty, for the peer node. `notes/` design notes. `PLAN.md` network plan.

Run:
- `cd contracts && forge test`
- `pip install -r requirements.txt && python3 -m pytest -q tests`
- `python3 data/iphone-20260923/replay.py --at-time 1790209000` (certificates in the capture have expired)
- `cd explainer && python3 build.py`
