# Assembly acceptance recordings

`build.py` embeds reviewed recordings in a self-contained watch page. It does not
create, replay or simulate events. Give each clip an explicit evidence label and
list its observed assertions and limits. Simulated native previews must have a
separate player and prominent simulation label; never describe them as enrollment.

Input JSON requires `title`, `sourceRevision`, `scope`, `limitations`, `recordings`
and optional `sources` (objects with `label`, `url`). Each recording requires a
local `path` relative to the manifest, reviewed `sha256`, `title`, `evidenceLabel`,
`description`, `assertions` and `limitations` arrays. The build refuses missing
claims or changed clip hashes and limits total embedded HTML to 9.8 MB.

Run `python3 design/assembly-recordings/build.py MANIFEST.json --out build/assembly-recordings.html`.
Review every clip, disclosure, and assertion against the captured event/receipt
files before publication. Publish with the dstack artifact workflow; verify
actual playback, pause, seek, fullscreen, offline HTML, archive hashes and phone
layout. Source links are supplemental evidence; they are not needed for playback.
