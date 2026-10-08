# Assembly acceptance scope

The 17-screen journey is a design prototype. The native Assembly work implements
a subset of that experience; a polished mockup is not evidence that enrollment,
independent signing or first installation succeeded. This matrix records the
current source scope and the recorded local-chain acceptance run. Recording
provenance is kept separate from design mockups and historical public receipts.

| Journey step | Native implementation | Observed acceptance |
|---|---|---|
| Download and first macOS open | Existing signed RC2 download; redesigned acquisition page is a mockup | Previous download checks exist; clean second-Mac Gatekeeper capture remains pending |
| Verify app, find peer, exchange key | Existing real participant loop, newly styled native status and geometric stage | Real Apple-attested Assembly participant exchanged the key with a separate seed process on the same Mac; local Anvil receipts verified |
| Claim participant receipt | Existing contract-backed account/claim flow and confirmation label | Recorded local Anvil claim succeeded after HTTP503 and stale-chain-clock retries; token1 owner is the personal account, not sponsor |
| Fold reveal | Bundled images only for verified original Base Sepolia receipts 1 and 2; other receipts display “ARTWORK NOT LOADED” | Recorded local-token screen accurately says ARTWORK NOT LOADED; public-Fold preview and future artwork automation remain separate |
| Inspect NFT | Explorer button maps the two known receipts to the reissued collection; arbitrary/local receipts are not presented as published artwork | Native action check pending; custom browser receipt page is a concept |
| Quit and reopen | Existing persisted identity/account and menu-bar lifecycle | Same-binary restart restored the same account/token with no mint and nextId2; updated local candidate also restored the receipt in a separate26-second clip |
| Developer introduction and invitation | Existing native alert explains setup; exports invitation and exact App ID | Invitation/save/import/cancel acceptance pending: no saved invitation was verified and remote OS-panel captures were blank; illustrated guide is not a native wizard |
| Developer portal, build and registration | External builder guide and existing tools | Independent Apple Developer team acceptance remains pending |
| Import invitation/request and approve | Existing file panels, validation and explicit account-control consent | Real independent-team consent/handoff and builder receipt remain pending |
| Report failure | Native events/backoff, technical-details drawer and new save-report panel | Recorded claim-pending state preserved genuine retry delay; proposed automatic terminal-error pause is not implemented |

Sources: [native GUI](../node/mac/GUI.swift), [build packaging](../scripts/release/build_mac.py),
[builder guide](builder-guide.md), [prior acceptance audit](acceptance-audit.md),
[Assembly concept source](../design/mac-journey/README.md).

A local Anvil chain is a real contract execution environment, but is not Base
Sepolia. Apple proof validation, local contract receipts, simulated previews and
production/testnet participant receipts must each be identified separately in
any recording. Another certificate from the publisher team is not evidence of
an independent-team builder upgrade. Preview/capture hooks are separately
compiled; ordinary releases do not select a simulated journey.

## Recorded join, including recovery

[Verification](../data/assembly-native-20261007/verification.json) independently
checks local mint status, personal ownership and sender/recipient key receipts.
[Participant events](../data/assembly-native-20261007/participant.jsonl) and
[seed events](../data/assembly-native-20261007/seed.jsonl) accompany the run.
The continuous 141-second AppKit content capture runs at its captured rate of
one frame per second with no cuts or speedup. It contains five distinct visual
states, all reviewed: attesting, receiving key, connected with claim pending,
claiming, and confirmed participant. It does not include the macOS desktop,
installation dialogs, signing setup, or a real independent-team handoff.

The first claim attempt received HTTP503 from the local relay; the next detected
a stale Anvil chain clock. The coordinator repaired the disposable test
infrastructure and the existing retry loop eventually confirmed the claim.
This is recorded recovery, not a claim of a frictionless first attempt. The app
kept its verified peer key while the claim was pending.

## Release boundary

The Assembly candidate is not admitted to the current public network. The
existing registry permits one approved code baseline; replacing that baseline
would stop admitting the RC2 binary. Public deployment therefore needs a
coordinated compatibility/cutover plan that preserves the original factory and
personal-account key namespace. This local acceptance run does not authorize or
prove that cutover. The persistent public peer remains separate.

[Parcel crypto checks](../data/assembly-native-20261007/parcel-crypto-tests.json)
exercise production transport authentication and pre-RPC import guards. They
are unit-level negative checks, not independent-team or whole-chain acceptance.

## Updated candidate reconnect

A separate, uncut 26-second recording shows the later candidate with refined
controls. [Its native events](../data/assembly-native-20261007/polished-participant.jsonl)
record a new successful Apple attestation, epoch1 key verification and the same
participant account/token with no new mint transaction. The local registry
baseline was changed deliberately for this candidate; this is not proof of a
seamless public RC2 upgrade. The earlier join clip retains its original controls.

## Findings retained in the recordings

The captured candidates display “Peer found” upon entering the key-request
stage, before observing a reply. Review identified this premature wording; the
subsequent source changes it to “Finding a peer.” The videos retain the captured
wording, rather than presenting a later UI build as the recorded executable.

## Additional checks without a movie

[Admission checks](../data/assembly-native-20261007/polished-admission-checks.json)
rejected different unadmitted code and a tampered executable page before the
local candidate was admitted. These are measured-code policy negatives, not a
recorded independent-team upgrade.

[In-place verification](../data/assembly-native-20261007/in-place-verification.json)
then verified the same existing enrollment/member under another newly admitted
local binary: new assertions succeeded without generating or attesting a new
App Attest key, the personal account/token stayed the same, nextId remained2,
and no new mint transaction was emitted. This additional result is log/chain
evidence, not part of the two real video clips. The local seed epoch changed
for instrumentation; the public network admission was not changed.

## Candidate provenance

The real join and refined reconnect movies use different executables. Their
signed executable SHA-256 values and unsigned/signed payload comparisons are in
[join signing](../data/assembly-native-20261007/candidate-builds/join-signing.json)
and [refined signing](../data/assembly-native-20261007/candidate-builds/polished-signing.json).
The corresponding candidate build manifests record compiler inputs and flags.
These captures do not imply that the final working-tree GUI is the exact binary
shown in every movie. The native simulated preview is a separately compiled
visual test, and never an Apple enrollment or a new on-chain mint.
