# L1 sweep with inline objects editable — 2026-11-10

Same corpus and edit script as the
[object-paragraph sweep](../edit-sweep-objects-2026-11-10/README.md): the 375 `.hwp`/`.hwpx`
files in `third_party/rhwp/samples`, `hwpmac-edit-check` (no flags) driven by
`scripts/edit-sweep.py`, one process per document, 180 s limit. The script edits the
first top-level paragraph of section 0 that accepts text: it types `[편집]`, composes
각 and 나, deletes 나, splits the paragraph, types `새 문단`, undoes and redoes, then
saves as HWP and HWPX and reopens both.

What changed is the engine: rhwp branch `hwpmac/native-actions` at `76c5d6572`. Before,
a paragraph holding an inline object — a treat-as-char table, picture or equation, a
footnote or endnote number — was refused outright. Now each inline object takes one
caret position (shown to the editor as U+FFFC); text edits go on the caret's side of
it and never remove it.

The marker check also changed. It used to look for the markers in the page text the
engine extracts for search. That extraction leaves out text that shares a line with a
treat-as-char table: the layout puts those runs outside a text line, and the extractor
only reads text lines. The check now searches the reopened document model; the old
page-text check is kept in each result as `markersInPageText`.

```sh
python3 scripts/edit-sweep.py build/DerivedData/Build/Products/Debug/hwpmac-edit-check \
  build/edit-check-v3 180 third_party/rhwp/samples/*.hwp third_party/rhwp/samples/*.hwpx
```

## Results

| | Object paragraphs (2026-11-10) | This run |
| --- | --- | --- |
| Documents edited, saved and reopened | 346 | **371** |
| Markers in the reopened model, HWP / HWPX | 346 / 346 | 371 / 371 |
| Markers in the extracted page text, HWP / HWPX | 346 / 346 | 354 / 354 |
| Saves with a rhwp content-loss report | 0 | 0 |
| Not edited: no editable paragraph in the first 200 | 25 | 0 |
| Not edited: password-protected / time limit | 3 / 1 | 3 / 1 |

25 documents could not be edited before (for example `equation-lim.hwp`,
`exam_math_8.hwp`, `nested_tac_table_wrap.hwp`, `ta-pic-001-r.hwp`, `표-텍스트.hwpx`),
and in 78 the edited paragraph is now an earlier one. No document edited before
failed now. The only refusal this change relaxed is the one for inline objects, so
these 103 edited paragraphs exercise the new path.

The 17 documents whose markers are missing from the extracted page text are all edits
in a paragraph that holds a treat-as-char table: the typed text ends up beside the table
on its line. `2010-01-06.hwp` rendered to SVG shows `새 문단` on the table's line; a
search of the saved file finds it at section 0, paragraph 1, offset 0. The search
importer uses the same extraction, so the fork now gives the native library a complete
variant that also reads runs outside text lines (`extract_page_text_complete_native`, used by
`rhwp_read_text` and `rhwp_export_text`); the engine's own page-text API is unchanged.
Rerunning the tool on those 17 documents with that library finds the markers in the page
text of 16 (`recheck-17.jsonl`). The one left, `nested_tac_table_wrap.hwp`, nests a
treat-as-char table inside a table cell; its markers are in the model (section 0,
paragraphs 0 and 1) but not in the extracted text.

Edit timings: median edit 0.66 ms (median of per-document medians); 95th percentile of
per-document maxima 1.6 s. Total 21 minutes.

Not checked here: whether Hancom's viewer opens these saves. That runs with the pending
Viewer batch.

`results.jsonl`: one line per document, as printed by the tool.
