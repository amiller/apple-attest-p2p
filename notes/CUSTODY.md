# Closure obligations before a fixed-code claim

This is a proof/work checklist, not evidence that the account is encumbered.
Do the identity/substitution experiment first. A TEE-held signing key is insufficient
if another credential can produce an accepted app under the same RP ID.

| Authority | Evidence needed | Current status |
|---|---|---|
| Source → binary | Measured builder or independent reproducibility that checks the exact approved artifact and dependencies | Not established for this iOS target |
| Bundle → constrained signature | TEE-generated signing key, pinned complete manifest including resources/entitlements; tampered artifacts rejected | Not implemented/deployed |
| Existing signing credentials | Complete inventory, no usable competing keys including pre-setup copies | Not established |
| New local certificates | Every authorized member/session/API path under the same policy | Not established |
| Cloud signing | All relevant users and permissions covered by custody | Not established |
| Account login and trusted devices | Competing sessions terminated; no human-controlled trusted device can reset/add authority | Not established |
| Security factors/recovery | Tested factor custody plus account/organizational recovery boundaries | Not established |
| Setup | Fresh measured controller authenticates state directly to Apple; completeness assumptions explicit | Not established |
| Renewal and agreement acceptance | Policy-preserving operation without giving a human unrestricted credentials | Not established |
| Controller update/rollback | Attested immutable policy or explicitly constrained upgrades; host cannot restore permissive state | Not established |
| Replacement supplier | A second independent team satisfies the same checks without manual trust in its owner | Not tested |

An authenticated list of current certificates is not an issuance history. Test
create/use/remove between watchdog polls, and observe behavior if its API access
vanishes. Monitoring and a bounded misuse window do not establish prevention.

Likewise, a controller that only signs an operator-chosen artifact hash does not
prove source provenance. Publishing a mapping `(App ID → commit)` cannot bind
execution if another same-identity binary can attest. An app's own assertion of
its hash or its embedded verification key does not repair that missing link.

Until these obligations close, use the trusted baseline/negative-result paper row.
There is no fallback that adds a trusted account owner and still satisfies the
requested developer-independent criterion.
