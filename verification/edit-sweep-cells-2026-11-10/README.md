# L3 table-cell sweep — 2026-11-10

Corpus: the 375 `.hwp`/`.hwpx` files in `third_party/rhwp/samples`, as in the
[L1 sweep](../edit-sweep-2026-11-09/README.md).

Engine: rhwp branch `hwpmac/native-actions` at `ad7c2c5` (table-cell editing in the
native editor).

Tool: `hwpmac-edit-check --cell` driven by `scripts/edit-sweep.py --cell` (one process
per document, 180 s limit). Among the first 200 top-level paragraphs of section 0 and
their first 8 controls, it takes the first table whose first cell's first paragraph
accepts text. There it types `[셀]`, composes ㄱ→가→각 and commits, splits the cell
paragraph, types `둘째 줄`, then undoes and redoes. It saves as HWP and HWPX, reopens
each file and reads the cell's first two paragraphs back from the model.

```sh
python3 scripts/edit-sweep.py --cell build/DerivedData/Build/Products/Debug/hwpmac-edit-check \
  build/cell-check-2 180 third_party/rhwp/samples/*.hwp third_party/rhwp/samples/*.hwpx
```

## Results

| | HWP | HWPX |
| --- | --- | --- |
| Cell edited, saved and reopened | 186 / 186 | 186 / 186 |
| Cell reads `[셀]각` then `둘째 줄…` after reopening | 186 / 186 | 186 / 186 |
| Saves with a rhwp content-loss report | 0 | 0 |

Not edited: 185 documents have no cell the probe accepted (the reasons were not
recorded per document), 3 are password-protected, 1 hit the time limit.

The edited cell was the first cell of a table held by body paragraph 0 in 90 documents
and by paragraphs 1–3 in most of the rest. Edit timings: median
1.4 ms (median of per-document medians), 95th percentile of per-document maxima 108 ms.

## How the check reads the cell

The first run read the reopened text with rhwp's text export, which lays out pages: in
narrow cells it breaks `둘째 줄` across lines, so 28 of 186 saves that held the text
were counted as misses (their text grew by the inserted characters). The check now reads the two paragraphs from the reopened model
through the input-method context at each paragraph start (plain-text copy refuses
ranges that hold objects, which some of these cells do). The numbers above are from
that check; `results.jsonl` holds one line per document.
