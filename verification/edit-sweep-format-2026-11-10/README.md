# L2 formatting sweep — 2026-11-10

Corpus: the same 375 `.hwp`/`.hwpx` files as the
[L1 sweep](../edit-sweep-2026-11-09/README.md) (`third_party/rhwp/samples` at rhwp v0.9.0).

Engine: rhwp branch `hwpmac/native-actions` (v0.9.0 plus the native formatting
actions), built with `scripts/build-native.sh`.

Tool: `hwpmac-edit-check --format` driven by `scripts/edit-sweep.py --format` (one
process per document, 180 s limit). It runs the L1 edit script, then selects the
first marker `[편집]각` and, as two undo entries, makes it bold and red
(`{"bold":true,"textColor":"#ff0000"}`) and centers its paragraph
(`{"alignment":"center"}`). After saving as HWP and HWPX it reopens each file,
selects the marker again and reads rhwp's character and paragraph properties.

```sh
python3 scripts/edit-sweep.py --format build/DerivedData/Build/Products/Debug/hwpmac-edit-check \
  build/format-check 180 third_party/rhwp/samples/*.hwp third_party/rhwp/samples/*.hwpx
```

## Results

| | HWP | HWPX |
| --- | --- | --- |
| Edited, saved and reopened | 320 / 320 | 320 / 320 |
| Markers found after reopening | 320 / 320 | 320 / 320 |
| Bold, red and centered after reopening | 320 / 320 | 320 / 320 |
| Saves with a rhwp content-loss report | 0 | 0 |

The 55 documents not edited are the same as in the L1 sweep: 51 have no plain body
paragraph in the first 200 (the script edits body text only, so documents that start
with tables or objects are skipped), 3 are password-protected, 1 hit the time limit.

Edit timings over the 320 documents: the median edit takes 0.7 ms (median of
per-document medians); the 95th percentile of per-document maxima is 1.7 s, from
re-pagination of long documents.

Whether Hancom's viewer opens these files is in
[hancom-viewer-format-2026-11-10](../hancom-viewer-format-2026-11-10/README.md).

`results.jsonl`: one line per document, as printed by the tool.
