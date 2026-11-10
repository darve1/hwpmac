# L1 sweep with object paragraphs editable — 2026-11-10

Same corpus, tool and edit script as the
[L1 sweep of 2026-11-09](../edit-sweep-2026-11-09/README.md): the 375 `.hwp`/`.hwpx`
files in `third_party/rhwp/samples`, `hwpmac-edit-check` (no flags) driven by
`scripts/edit-sweep.py`, one process per document, 180 s limit. The script edits the
first top-level paragraph of section 0 that accepts text.

What changed is the engine: rhwp branch `hwpmac/native-actions` at `ad7c2c5`. Before,
the native editor refused any paragraph holding a control other than the
section/column definitions (fields, bookmarks, floating pictures and tables, …). Now
it edits such paragraphs as long as no control is anchored inside the text it
removes; inline (treat-as-char) objects are still refused.

```sh
python3 scripts/edit-sweep.py build/DerivedData/Build/Products/Debug/hwpmac-edit-check \
  build/edit-check-v2 180 third_party/rhwp/samples/*.hwp third_party/rhwp/samples/*.hwpx
```

## Results

| | 2026-11-09 | This run |
| --- | --- | --- |
| Documents edited, saved and reopened | 320 | **346** |
| Markers found after reopening, HWP / HWPX | 320 / 320 | 346 / 346 |
| Saves with a rhwp content-loss report | 0 | 0 |
| Not edited: no editable paragraph in the first 200 | 51 | 25 |
| Not edited: password-protected / time limit | 3 / 1 | 3 / 1 |

Of the 346, 26 documents could not be edited before (for example `bitmap.hwp`,
`mix-shape-01.hwp`, `test-image.hwp`), and in 90 the edited paragraph is now an earlier
one. The only refusal this change relaxed is the one for controls, so each of these
116 edited paragraphs holds a control other than the section/column definitions.
Those 116 documents exercise the new path; whether Hancom's viewer opens their saves
is in [hancom-viewer-objects-2026-11-10](../hancom-viewer-objects-2026-11-10/README.md).

For the 25 still not edited, every top-level paragraph of section 0 was refused (the
probe ran past the end of the section). Why each was refused was not recorded; the
[cell sweep](../edit-sweep-cells-2026-11-10/README.md) covers documents that are
mostly tables.

Edit timings: median edit 0.96 ms (median of per-document medians); 95th percentile of
per-document maxima 2.0 s (re-pagination of long documents). Total 23 minutes.

`results.jsonl`: one line per document, as printed by the tool.
