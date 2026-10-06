# Sample app first-run contract

This is the acceptance specification for the next app build, not current behavior.

Opening the app begins enrollment automatically. No network chooser, configuration
editor, wallet connection or gas purchase. The distributed bundle pins the network
identity and compatible protocol/policy; operational HTTPS endpoints are published.

| State | Visible message | Evidence needed to advance |
|---|---|---|
| Preflight | Checking your Mac… | Supported OS/device/API and valid configuration |
| Connecting | Connecting to the testnet… | Expected chain/network and reachable relay |
| Attesting | Verifying this app… | Authentic evidence accepted under current policy |
| Admitted | Getting your testnet credential… | Confirmed, idempotent faucet receipt for this participant |
| Discovering | Finding a peer… | Authenticated peer/session binding |
| Active | You're connected | Verified exchange with a peer; timestamp visible |
| Waiting | Admitted; waiting for a peer | Admission holds, no current peer exchange |
| Offline | Network unavailable; retrying… | Bounded backoff; preserve identity and pending submissions |
| Rejected | This build isn't admitted | Stop authorization; show release/update details |
| Unsupported | This device doesn't support this testnet | Explain macOS/iOS 27 evidence requirement |

The main window shows network name, credential/claim receipt, peer count, last
verified exchange and current state. Technical details expose code identity,
signer, policy, transaction IDs and explicit RPC/admin trust. Logs and agent JSON
status report the same state, not guessed UI progress.

Closing the Mac window leaves a visible menu-bar participant; Quit stops it.
Launch at login is a separate explicit preference. Do not promise pre-login
daemon support. On phones, explain that participation requires the foreground.

The faucet has no monetary value. Its meaning must be settled before copy is
finalized: the app's private identity key is generated locally, never sent from a
faucet. The existing gas sponsor currently owns the on-chain claim recipient.
Implement a participant-bound credential or recipient path before saying the user
received tokens. Restart must not create a new key/claim merely to recover.

Developer/agent acceptance: one documented build command, one launch command
through LaunchServices (App Attest is unsupported for the directly exec'd SSH
binary in the retained experiment), structured status, explicit errors, and the
same protocol as the GUI. No mock attestation fallback on unsupported hardware.
