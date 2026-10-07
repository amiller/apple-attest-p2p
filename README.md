# apple-attest-p2p

Admission for a permissionless peer-to-peer network of iPhones and Macs, using App Attest on iOS/macOS 27. On those versions the App Attest attestation and assertions carry the running app's CDHash, so a contract can admit a device only if it runs a registered build. Copied out of `edge-tee/ios-app-attest` on 2026-10-06.

Release work: [Mac reproducibility, fork/CI signing, and TestFlight checklist](release/README.md)
and [first-run user flow](release/user-flow.md). The Mac participant release is available; the second-team and iPhone acceptance runs remain in progress.

## Try the Mac demo

Download **AttestNode-macOS27-arm64-v0.1.0-rc.2.zip** from the
[latest release](https://github.com/amiller/apple-attest-p2p/releases/latest).
On a supported Apple silicon Mac running macOS 27 with Full Security, open the
app and keep it running. It joins the research testnet and claims a participant
NFT automatically; no wallet setup or payment is required.

- [What the app does and what it proves](release/PRD.md)
- [First-run flow and troubleshooting](release/user-flow.md)
- [Build/sign with your own Developer team for Level 2](release/builder-guide.md)
- [iPhone/TestFlight status and testing evidence](release/iphone-simulator-validation.md)

The independent-team handoff still needs a positive hardware acceptance run.
iPhone build 4 has been uploaded to TestFlight, but tester access and installed
code admission are not yet verified. See [source-history notes](release/source-history.md)
when comparing original build-manifest commit IDs with this public history.

Layout:
- `contracts/` Foundry project: `CDRegistry` (admits any signer's re-sign of the approved build: code slots, masked page 0, CD header and entitlement key set pinned; RP ID = sha256(application-identifier)), `AppleAttestRegistryV1` / `MacAppAttestV1` adapters, `DemoV1` (application), P-384 and DER parsing, deploy script (`script/Network.s.sol`, outputs in `network/`). forge-std and OpenZeppelin 4.9.6 are vendored in `lib/`.
- `verifier/`, `tests/`, `trust/`, `scripts/` Python App Attest verifier, its tests, the pinned Apple root, and build/inspection scripts (`cd_layout.py`, `cross_signer.py`, `macho_pages.py`).
- `app/` probe iOS app source; `app/macos/` macOS probe, demo (`demo/Chain.swift`), custody experiment and evidence.
- `data/` iPhone captures (iOS 27, 2026-09-23; iOS 18.5 XS, 2026-10-05), local re-signing matrix, explainer inputs (`data/ios`).
- `explainer/` single-page explainer, built from `template.html` + `data/ios`.
- `node/` peer node: `shared/` (Swift: Node, Chain, Protocol), `mac/` (CLI app + build script), `ios/` (SwiftUI shell, simulator build), `relay/relay.py` (gas sponsor + peer mailbox), `run_p2p.py` (live run driver), `anvil_up.sh`.
- `data/p2p-run-20261006/` live two-node run on anvil and Base Sepolia, iOS simulator check (`RESULTS.md`). `notes/` design notes. `PLAN.md` network plan.

Run:
- `cd contracts && forge test`
- `pip install -r requirements.txt && python3 -m pytest -q tests`
- `python3 data/iphone-20260923/replay.py --at-time 1790209000` (certificates in the capture have expired)
- `cd explainer && python3 build.py`

Live network (Mac mini = `mini-mesh`, macOS 27 + Xcode 27):
1. Build on the mini (unlocks the dsmack keychain in the same ssh session):
   `rsync -a --exclude build node/ mini-mesh:apple-attest-p2p/node/`
   `ssh mini-mesh 'export KEYCHAIN_PW=...; cd apple-attest-p2p/node/mac && ./build.sh honest && ./build.sh resigned && ./build.sh modified'`
2. `node/mac/pull_builds.sh data/<run>` copies the builds and writes `contracts/network/cd-args-macos.json` (approved = honest) and the `node-*` test fixtures.
3. Tunnel: `ssh -N -R 18555:127.0.0.1:18555 -R 18556:127.0.0.1:18556 mini-mesh`.
4. Anvil: `node/anvil_up.sh data/<run>/anvil` (anvil `--hardfork osaka` on 18555, deploy, relay on 18556), then
   `PRIVATE_KEY=<anvil key 0> python3 node/run_p2p.py --deploy contracts/network/deploy-anvil.json --rpc http://127.0.0.1:18555 --rpc-mini http://127.0.0.1:18555 --relay http://127.0.0.1:18556 --relay-log data/<run>/anvil/relay.jsonl --out data/<run>/anvil --builds data/<run>/builds --settle 0`
5. Base Sepolia, with `PRIVATE_KEY` (0x97883cb4) and `ETHERSCAN_API_KEY` sourced from `tee-bridge/.env` into the environment:
   `cd contracts && MAC_BUILD=network/cd-args-macos.json DEPLOY_OUT=network/deploy-base-sepolia.json forge script script/Network.s.sol --rpc-url https://sepolia.base.org --broadcast --slow --gas-estimate-multiplier 200 --verify`
   (adapters: `scripts/verify_standard_json.py`), relay with `--rpc https://sepolia.base.org --settle 4`, then `run_p2p.py` as above with `--rpc[-mini] https://sepolia.base.org --settle 4`.
6. iOS simulator: `ssh mini-mesh apple-attest-p2p/node/ios/build_sim.sh`, `simctl install`, launch with `SIMCTL_CHILD_NODE_CONFIG=<json> SIMCTL_CHILD_NODE_ROLE=connect`.

`--gas-estimate-multiplier 200` is required: forge's estimate for `registerBuild`/`setBuild` is below the EIP-7623 calldata floor.
