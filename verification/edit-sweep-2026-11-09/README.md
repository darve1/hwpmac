# L1 edit-path sweep — 2026-11-09

Corpus: the 375 `.hwp`/`.hwpx` files in `third_party/rhwp/samples` at rhwp v0.9.0
(c9095c5). Their provenance is rhwp's own sample set, not yet a curated public-sector
corpus.

Tool: `hwpmac-edit-check` driven by `scripts/edit-sweep.py` (one process per document,
180 s limit). For each document it saves the untouched document as HWP and HWPX
(baseline), then on the first top-level paragraph of section 0 that accepts text runs:
insert `[편집]`, compose ㄱ→가→각 and commit, compose ㄴ→나 and commit, Backspace,
Return, insert `새 문단`, undo, redo. It saves HWP and HWPX, reopens both and reads the
text back. Results: `results.jsonl` (one line per document, NFC file names).

## Results

| | Count |
| --- | --- |
| Documents | 375 |
| Opened | 372 (3 failures are password-protected files, expected) |
| Edited, saved as HWP and HWPX, reopened | **320 (85.3 %)** |
| — edits present after reopening | 320 / 320 in both formats |
| — rhwp content-loss reports | 0 |
| No editable top-level paragraph in section 0 (first 200) | 51 |
| Engine did not finish (stopped after ~12 min) | 1 (`issue2063_huge_cellbreak_table.hwp`) |

Text-length change after editing is 10 characters for most documents (5 + 4 inserted
plus one paragraph break). Larger changes were checked on two documents by diffing the
baseline and edited text: the new paragraph inherits a bullet (❏), and content pushed
to a new page adds a page-number footer or repeats a table header row. These are layout
consequences, not lost or extra content. 35 (HWP) / 36 (HWPX) documents end up with a
different page count for the same reason; whether 한글 paginates them the same way is
not checked.

Edit latency per operation (re-pagination runs after every edit in rhwp's native session):

| | p50 | p90 | p95 | max |
| --- | --- | --- | --- | --- |
| Per-document median | 0.9 ms | 361 ms | 847 ms | 1.2 s |
| Per-document maximum | 1.4 ms | — | 1.7 s | **300.5 s** |

33 documents have at least one edit over 1 s and 2 over 10 s.

## Not checked

- Whether 한글 opens the saved files without a corruption warning (needs 한컴오피스).
- Editing inside table cells, text boxes, headers/footers (outside L1).
- Encrypted documents (the sweep does not supply passwords).
