# NFT release rollout

The new Base Sepolia contracts are deployed and paused. Public addresses and
transaction hashes are in `contracts/network/deploy-nft-base-sepolia.json`.
Their runtime bytes match the local artifacts; see `nft-base-deployment-check.json`.

Candidate `eace7a3` reproduced independently on the Mac and GitHub CI, was signed
and notarized, and passed the signed-payload comparison. Its code was admitted
while the new network remained paused. The evidence in `reproducibility-nft-base.json`,
`notarized-payload-nft-base.json`, and `admission-nft-base.json` describes that
candidate, **not the final distribution**.

The first attempted relay update was rejected by automatic approval review
because replacing the root network would disrupt the existing shared-key demo.
No service change occurred. The revised rollout preserves root routes and their
network, seed, mailboxes and transaction journal, and adds `/nft` routes within
the same service. One sponsor queue serializes transactions across both networks.
The compatibility test checks network routing, retained journal state, separate
mailboxes, and rejection of cross-network categories.

The `/nft` endpoint changes a measured app input. Rebuild and notarize this
candidate again, replace the paused NFT network's baseline with its exact signed
CodeDirectory, and recheck independent reproducibility before distribution.
`scripts/release/admit_mac_release.py` performs only admission on a paused test
network and journals transaction hashes before submission. It never activates
the network and refuses to reuse an existing output journal.

Remaining rollout steps: deploy the compatibility relay; verify both `/info`
routes and no pending transactions; finish the updated signed candidate; activate
only the NFT network; run a separate persistent NFT seed; verify an automatic
participant claim, restart, and receipt ownership; package the release and real
screenshots. Keep the original seed running. Clean second-Mac and independent
developer-team acceptance remain separate required tests.
