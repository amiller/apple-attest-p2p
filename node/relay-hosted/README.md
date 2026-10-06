# Durable testnet relay

This untrusted relay sponsors on-chain transactions and carries encrypted parcels.
It never receives the shared signing key. `network.json` pins the test deployment;
`abi.json` is generated from the checked-in contracts. Dependencies are locked.

The deployed instance uses the existing pod's isolated Deno container runtime,
with persistent `ctx.dataDir` and `ctx.env.PRIVATE_KEY` / `RPC_URL`. The sponsor is
a dedicated Base Sepolia account. Its key is not in source, tarballs or build logs.
No other application or signing account needs that credential.

The relay journals each exact signed transaction before sending it; restarts and
identical retries recover the same transaction hash. Transactions serialize to
avoid sponsor nonce conflicts. Mailboxes have expiry, size and count limits.
The shared key and App Attest identity remain on peers. RPC and relay availability
remain trust/availability assumptions; this is not a light client.

Development command (provide a matching disposable test account and network):

```sh
deno task check
RELAY_DATA=/private/path/to/state deno task start
```

The public service accepts only Join, Bootstrap and Receipt for its configured
category. It does not expose token claims, administrator calls or STOP controls.
Mailboxes are untrusted and unauthenticated transport: malicious traffic can
still delay or discard delivery. Peers verify chain/session/key bindings.

The transaction journal has a hard 10,000-entry cap; plan maintenance before
reaching it. Do not delete pending entries. RPC failures return retryable errors.
