# Main collection: Fold

The main collection keeps the name **Attest Testnet Research Badges** (ATTEST).
There is no version label. `ResearchCollection` adds the porcelain-and-vermilion
Fold artwork to the existing research receipts.

Each token has exactly its original receipt number and owner. The original
`ResearchBadges` contract remains the attestation, consent and replay-protection
engine; its address remains pinned in existing personal accounts. Reissuing art
does not rotate keys, replace accounts, or require another enrollment. Historical
receipts remain visible on chain and are linked from the new metadata.

Artwork is derived from the source receipt's chain, contract and token number,
so moving the presentation to a new collection does not change the sculpture.
The publisher registers a PNG URI, its SHA-256 and the renderer source SHA-256.
Any caller can then issue the token to its original owner; the caller cannot
redirect it. Both collections are non-transferable. Level 2 retains its existing
independent-team and parent-receipt checks in the original receipt engine.

Image URLs use immutable Git commit paths. The artwork registration can be
updated by the collection owner until explicitly frozen. Freezing makes the URI
and hashes immutable, not the availability of an external image host. Images
are not stored on chain. Tokens cannot be issued before their art is registered.

## Publication procedure

1. Run `forge test --root contracts` and render/inspect artwork from public receipt
   identities. Commit images and renderer manifests; use full-commit image URLs.
2. Prepare an artwork array with `tokenId`, `manifest` (repository-relative) and
   `image` (public HTTPS URL). Run `scripts/release/publish_collection.py` with
   `--network`, `--artworks`, and `--out`. This is read-only by default and verifies
   live receipt policy, owners, public image bytes and renderer identity.
3. Pause sponsor writes on the relay and drain pending transactions. Broadcast
   with `--broadcast --relay <NFT relay URL>` and the dedicated testnet publisher
   key supplied through `PRIVATE_KEY`. Preserve the transaction journal if any
   step fails; reconcile its hashes before retrying. Never run two publishers.
4. Verify the resulting metadata, owners and explorer links, then restore relay
   sponsor writes. Save the public deployment record; the private journal records
   exact signed transactions for recovery.
5. Promote the new collection links in the handoff. Keep the old receipt and
   account-factory addresses as claim-policy configuration.

## Integration status

The collection contract and publication helper are implemented; deployment is
recorded separately. Existing released apps still open the old receipt explorer
link. A subsequent app release must display the artwork collection separately
from the pinned receipt policy. Updating an executable requires admitting its
new measured code before it can join the existing network.

Future claimants also need artwork rendered, published and issued. The helper's
`--collection` mode supports additional receipts. A continuously operated render
worker and app “Preparing your artwork” state are not yet implemented; do not
promise instant artwork delivery for future claims. Original network joining
and receipt claiming continue to work independently of artwork publication.
