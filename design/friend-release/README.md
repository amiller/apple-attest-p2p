# Verified friend handoff

Build an offline download-and-first-run guide only after the actual release is
verified. `build.py` requires a manifest with `releaseVerified: true`, exact
version/source/ZIP SHA-256, GitHub asset and release URLs, supported requirements,
observed checks, current steps and remaining limits. Reviewed PNG screenshots are
embedded only when their hashes match. It does not substitute mockups for real
release screenshots or accept a pending release as ready.

Run `python3 design/friend-release/build.py MANIFEST.json --out build/friend-release.html`.
Use the dstack artifacts workflow to publish the reviewed HTML and preserve old
links. Verify anonymous download/checksum, hosted/offline bytes, responsive layout
and the actual release links before sharing it. Keep unlisted URLs and private
release journals out of the public source manifest.
