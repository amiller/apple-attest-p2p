# Mac visual journey — Assembly

The selected Assembly direction uses oversized sans-serif typography, ivory and ink,
vermilion edition numbers and cobalt network cues. Real Fold artwork leads the
reward screens; consent and failure states stay restrained and readable.

This is a proposed interface, not the released application. Its 17 screens walk
through acquisition, first open, verification, peer exchange, artwork preparation,
Fold reveal, receipt inspection, return, independent signing and account handoff,
and a useful failure report. Browser, OS and terminal handoffs are reconstructions.

Run `python3 design/mac-journey/build.py` and open
`build/mac-visual-journey.html`. The output is self-contained. Its buttons and
arrow keys advance the storyboard; it makes no network requests, submits no
transactions, exports no files and installs nothing. The explicit external NFT
link opens the real explorer. Use the four chapter selectors or numbered index
to jump between screens.

The embedded sculpture is the actual artwork for participant #2; its use in the
future builder-success screen shows the preserved participant Fold, not invented
builder-mint evidence. The real RC2 status capture and evidence links are tucked
under the implementation disclosure, rather than used as proposed design.

All 17 screens were captured in an isolated Chromium browser and checked for
horizontal overflow at 1360px and 390px. Navigation, screen buttons, chapter
selection and arrow keys were checked. This is prototype validation, not native
Mac acceptance testing. PNG captures remain under `build/assembly-journey-review/`.

The report is published with the existing dstack report publisher's `--interactive`
flag, which allowlists the SHA-256 hash of the embedded script. Do not publish it
as a static report: its screen selector would be disabled by content policy.

Outstanding product implementation: visual redesign; app artwork integration;
automatic artwork delivery; proposed error/report interface; clean friend first
open and independent-team upgrade acceptance. See release/PRD.md and the actual
builder guide for current behavior and requirements.
