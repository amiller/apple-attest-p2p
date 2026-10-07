# Try AttestNode

**Mac prerelease:** Apple Silicon and macOS 27 are required. The download is in a
private GitHub repository, so you need repository access. This candidate has
passed a real Mac network/claim run; a clean second-Mac first-open test and the
independent-developer upgrade are still awaiting acceptance.

1. Download `AttestNode-macOS27-arm64-v0.1.0-rc.2.zip` from the
   [release](https://github.com/amiller/apple-attest-p2p/releases/tag/v0.1.0-rc.2).
2. Extract it and open **Node.app**. Complete macOS's normal first-open confirmation
   if it appears. You do not need Xcode, a developer account, a wallet, or gas.
3. Wait for **You’re connected** and **Participant NFT confirmed**. The observed
   first run took about 48 seconds; network delays can take longer. The app retries
   connection problems and shows its current progress.
4. Choose **View NFT receipt** to inspect your testnet souvenir. Closing the window
   leaves your peer running; Quit stops it. Reopening restores your existing NFT.

![The actual connected app](../data/nft-base-live-20261007/participant-claimed.png)

For Level 2, choose **Developer upgrade…** and follow the
[builder guide](builder-guide.md). You need your own paid Apple Developer team,
independent of the publisher, and an account-specific signed build. Keep the
original app and its Keychain intact until the handoff completes. This upgrade
is implemented but still needs its first real second-team acceptance run.

These are research testnet receipts with no monetary value. Your personal NFT
key is separate from the shared testnet key and lives in your Mac's Keychain.
There is no sponsor recovery if you lose it. App Attest does not provide a
permanent Mac-owner identity; claim limits are per app key and developer team.

For an agent or technical reviewer: the [observed transcript](agent-transcript-nft-base.md),
[PRD](PRD.md), and [release manifest](v0.1.0-rc.2.json) state exactly what was checked
and what remains unverified.
