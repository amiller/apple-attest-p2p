# Acceptance audit — 7 October 2026

The goal is **not complete**. Gabe has now reported successful Mac participation
after enabling Full Security and backing up the pending enrollment state. The
user supplied a token-2 explorer link; independent receipt verification and a
friend restart capture remain pending. This is a reported success, not proof of
a frictionless first install or of Gatekeeper settings. The second-team builder
journey remains unverified. Friends with iOS 27 devices are available, and their
TestFlight flow is now active release work. Credentials stay on that participant's machine. A second-team signing
identity cannot be substituted with another certificate from the publisher team.

| Requirement | Authoritative evidence | Result |
|---|---|---|
| Friend can obtain the signed app | Unlisted handoff browser download matches RC2 ZIP SHA-256; HTML, archive and manifest verified | Download ready; clean second-Mac install unverified |
| Join and automatically claim participant NFT | `data/nft-base-live-20261007/participant.jsonl`, real screenshot, successful Base Sepolia mint receipt | Verified on signing Mac, two processes |
| Personal ownership and restart without duplication | On-chain owner differs from sponsor; packaged restart restores NFT 1; `nextId()` remains 2 | Verified for recorded participant; friend run pending |
| Own developer-team upgrade and builder NFT | Contract policy/rejection tests, implemented UI/handoff, builder guide | Positive second-team journey unverified |
| Real journey screenshots | Actual connected/claimed and restart captures retained | First-open, developer setup and builder-success captures still required from acceptance run |
| Reproducible agent transcript | Exact commit, commands, events, receipt, ownership and restart recorded | Level 1 recorded; second signing identity and Level 2 transcript pending |
| Agent can independently check receipts | `verify_badge_receipt.py` verifies actual mint event and current ownership without keys | Level 1 command passed; unrelated enrollment receipt rejected; optional builder check awaits a real builder NFT |
| Honest identity and trust limits | PRD, builder guide, handoff page, implementation notes | Documented; no unique-Mac-owner guarantee |
| Persistent network | NFT user-session launch agent observed running with recent reachable events | Live; not a pre-login daemon or availability guarantee |

The signing Mac still reports `assessments disabled`. Its notarization, signature,
and stapled ticket checks do not prove a clean Gatekeeper first-open experience.
The published source remains private; Level 2 requires repository access.
iOS/TestFlight is active; see `iphone-simulator-validation.md` for simulator and
injected-callback evidence and the remaining hardware/distribution gates.

## Read-only receipt check

In a source checkout with the deployment scripts' Python `web3` dependency:

```sh
python3 scripts/release/verify_badge_receipt.py \
  --account 0xAc089f563703F8811073C758d6E1E8aAD89C7cCD --token 1 \
  --mint-tx 0x111c7b5e723dc290df0694c6bcc34c6cf4f1c8b04b321fee52391a08c4b56037
```

For the friend's run, use their account, token and mint transaction. After the
upgrade, add `--builder-token TOKEN` to check linked ownership and the independent
team hash. This is an RPC-backed check, not a light-client proof, a check of who
held Apple credentials, or proof of a clean installation. The optional builder
branch has not yet been exercised against a real second-team mint.

## Complete the remaining run

1. On the second Mac, record its OS/architecture and Gatekeeper status. Download
   through the handoff link, verify the ZIP checksum, and open normally. Capture
   actual first-open prompts or errors; do not disable Gatekeeper for acceptance.
2. Record the connection/claim screen, personal account, token, and receipt.
   Quit/reopen; confirm the same account/token and no duplicate mint. Use the
   verifier above with the friend's values. Do not send their Keychain contents.
3. Follow `builder-guide.md` using the invitation's bundle ID and the friend's
   independent team. Record build/source hashes, public signing Team ID,
   registration receipt, and the actual handoff screens. Keep private credentials
   local and keep the original app/key until handoff confirms.
4. Confirm the builder NFT at the original participant account, with its Level 1
   parent and independent team hash. Capture the final screen and receipt; retain
   any failure, expired request, or retry in the transcript.
5. Reconcile these observed results into the PRD and handoff page as a new report
   revision. Only then re-audit completion of both friend-facing journeys.

Further synthetic captures or repeated tests on the publisher's team cannot
supply the missing evidence. No external friend has been contacted by the agent.
