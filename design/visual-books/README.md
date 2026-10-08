# AttestNode visual design books

Three proposed art directions for the accepted Mac journey:

- **Kiln:** sculptural porcelain, saturated red, expressive serif display.
- **Resonance:** deep ink, mineral light, abstract interference patterns.
- **Assembly:** bold typography, geometric progression, vermilion and cobalt.

Each PNG is a generated art-direction board; each corresponding PDF has three
pages: concept board, design system, and journey treatment. These are concept
studies, not implementation screenshots or replacement minted NFT images.

Generated with the built-in image_gen tool. `prompts.json` records the exact
initial prompts and corrective edit prompts. The edits removed misleading
identity-verification and developer-handoff captions. Remaining artwork copy is
exploratory: the written rules govern implementation. In particular the artwork
must not introduce a new Keep running/Pause gate, fictional peer counts or any
promise of unique human/device identity. Only explicitly confirmed ownership
handoffs change account control.

Run `python3 design/visual-books/build.py` to generate the self-contained
comparison and per-direction print HTML under `build/visual-books/`. The comparison
uses an inline script solely for image enlargement and performs no network calls.
Its external PDF links go to this repository. When using the report publisher,
pass `--interactive` to allowlist that script. The source PNGs remain full-size.

The PDFs were printed with Chromium using `print_background=True` and
`prefer_css_page_size=True`; CSS defines three A4 landscape pages per book.
Desktop/mobile layout, image decoding and all three enlargement dialogs were
checked. The PDF page count is three for each direction.

Recommendation: start with Assembly's readable graphic hierarchy, with Kiln's
material and light. Keep the existing 17-screen journey; change its presentation
only after choosing an art direction. The production app is unchanged.
