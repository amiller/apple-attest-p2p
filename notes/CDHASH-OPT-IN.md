# CDhash opt-in: macOS evidence now available

**September 23 update:** iOS is no longer untested. An ad hoc iPhone build with this
opt-in reports the CDHash in enrollment and assertions ([iPhone results](../iphone-20260923/RESULTS.md)).

**September 16 update:** the [real Mac substitution experiment](../macos/RESULTS.md)
verifies the Apple-rooted CDHash in both attestations and assertions. Modified code
can reuse an enrolled key, but the assertion carries its changed hash and is
rejected by an approved-CDHash policy. iOS support remains untested. The following
September 9 inventory is historical, superseded for the tested macOS 27 path.

On 2026-09-09, read-only inventory on the Mac decoded the existing `dsmack provider
dev` provisioning profile (platform OSX). Its entitlements include:

```xml
<key>com.apple.developer.devicecheck.app-attest-opt-in</key>
<array><string>CDhash</string></array>
```

This corroborates the existence of the entitlement in a local provisioning artifact.
It is stronger than the earlier paper note's sole forum mention, but it is not a
fresh App Attest response, and the profile's CMS signature was not separately
validated in this inventory. No code-measurement export or iOS support is inferred.

The earlier [paper evidence](../../paper/sections/evidence/EVIDENCE-appattest-macos27.md)
already identified the open question. The matching [developer report](https://developer.apple.com/forums/thread/836329)
mentions the entitlement but describes App Attest failing on a macOS beta; it does
not establish that a remote verifier receives a measured cdhash.

Add an iOS comparison if the test App ID/profile supports this opt-in: capture with
and without it, inspect every authenticated extension and certificate field, and
compare against the signed bundle's local CodeDirectory digest. Test whether the
value changes on code substitution and whether it reflects the current binary in
assertions after updates. Do not treat the entitlement's name alone as proof that
it supplies the missing code binding. A real authenticated digest would change the
construction, so this branch should remain open rather than be dismissed.
