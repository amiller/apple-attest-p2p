# Native Mac participant and recovery tests

Real App Attest on mini-mesh, development-signed GUI, isolated Anvil chain 31337.
These are protocol tests, not an independent-machine or public release claim.

- Automatic enrollment, shared-key import and verified sender/recipient receipts.
- Same GUI executable serves an onward peer, which independently verifies the key.
- Restart resumes member `0xfe3b5614…706183` and reacquires the same epoch-2 key;
  `restart.jsonl` records the new receipt. No fresh enrollment was required.
- Explicit administrator epoch changes preserve network and member identity;
  the seed bootstraps the next shared key. Old keys are not erased from prior peers.
- The durable relay accepts real enrollment/assertions and encrypted parcels;
  `durable-enrollment.jsonl` records a fresh third peer's successful exchange.
- Stopping and restarting the relay with the same journal causes bounded retries,
  then automatic identity resume and participation (`relay-restart.jsonl`).
- Signature comparison accepts only minimal zero padding to 16-byte signature
  alignment; nonzero or excessive padding remains rejected.

Live testing exposed and fixed a HELLO/PARCEL ordering race and ERROR-response
loop. The successful final run uses unsigned GUI hash
`c94dca4eba18e59c593964b8d1af2f0e52cb7b9b7809dacb962bf6123c7e514e`.
The release-network configuration was embedded afterward and changes that hash.

Window screenshot capture was unavailable in the remote session. The UI state
and receipt were checked through the same event stream and status JSON the window
uses; visual layout and clean-machine interaction still need a human/GUI check.
