# Two-level NFT implementation notes

Status: local contract implementation and tests; not deployed or wired to the app.
The signed v0.1.0-rc.1 app still implements only shared-key participation.

`ResearchBadges` is separate from the legacy sponsor-owned NFT action. It uses a
normal sponsored network `Receipt` action, with `envelopeDigest` bound to the
badge's domain-separated `claimDigest`. The app must explicitly produce this
additional receipt after acquiring the shared key; an ordinary peer-exchange
receipt cannot be repurposed as a badge claim.

The recipient also signs the claim digest, using an EOA or an ERC-1271 personal
account. The relay cannot change the recipient, level, parent, key identity, or
deadline. It may submit the transaction and pay gas. The intended zero-setup
client creates a personal account locally; its key is distinct from the shared
network key. Personal account implementation, persistence, recovery and the
cross-team handoff remain to be implemented and tested.

The evidence-enabled Apple adapter stores only successfully verified assertion
context, CDHash, RP hash, counter, and verification time. Enrollment alone is not
claim evidence. Badge validation checks the exact network request context, fresh
receipt deadline, active member, current code admission, and recipient consent.
An epoch change invalidates outstanding key-receipt contexts.

Level 1 is limited to one claim per network category/App Attest key. It is not
one claim per physical Mac, human, or wallet. Level 2 is limited to one claim per
verified non-publisher signing team and one upgrade per Level 1 badge. Both
badges belong to the same recipient and are non-transferable historical receipts.
These limits are explicit research-demo policy, not evidence of human uniqueness.

`CDRegistry.teamIdHash` uses SHA-256 of the explicit sealed
`com.apple.developer.team-identifier` entitlement. Missing team entitlements return
zero and cannot qualify for Level 2. An App ID prefix is not substituted. Registry
registration is permissionless and does not prove an Apple signature: the live
App Attest assertion for that CDHash and RP is the necessary second check.

Deployment requires a new evidence-enabled adapter/network configuration. The
live deployed contracts are immutable; changing source files does not upgrade
them. Preserve the current seed until replacement network admission and client
builds are verified. Measure the additional enrollment/receipt gas before launch.

Tests:

```sh
forge test --root contracts
```

`ResearchBadgesTest` isolates badge policy with mocked verified evidence. It is
not a device integration test. `AppleAttestRegistryV1Test` separately exercises
actual Apple certificate/assertion fixtures and verifies that failures/replays do
not write successful assertion evidence. Neither substitutes for the pending
second-team, real-device NFT journey and screenshots.
