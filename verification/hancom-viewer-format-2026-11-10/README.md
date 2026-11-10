# Formatted saves opened in Hancom Office HWP Viewer — 2026-11-10

Oracle: 한컴오피스 한글 Viewer 12.31.9 for macOS, as in
[hancom-viewer-2026-11-09](../hancom-viewer-2026-11-09/README.md).

Input: the edited saves of the [L2 formatting sweep](../edit-sweep-format-2026-11-10/README.md)
(the L1 edit script plus bold, red and centered text), for the 316 documents whose
original the viewer opens: 316 HWP and 316 HWPX files. They were copied to
`build/format-viewer/NNNN.formatted.{hwp,hwpx}`, where `NNNN` is the sweep index
(`names.json` maps it to the sample file name).

Method: `hwpmac-viewer-check` (Release build) on each file, 20 files per process:

```sh
tr '\n' '\0' < build/format-viewer/files.list | caffeinate -i xargs -0 -n 20 \
  build/DerivedData/Build/Products/Release/hwpmac-viewer-check >> build/format-viewer/results.jsonl
```

## Results

| Saved file | Opened |
| --- | --- |
| Formatted, HWP | 314 / 316 |
| Formatted, HWPX | 316 / 316 |
| **All** | **630 / 632 (99.7 %)** |

The two failures are the documents that already failed after the L1 edit alone, with
the same warning dialog ("한컴오피스 한글 Viewer 중요한 경고"):

| Document | File |
| --- | --- |
| `hwp3-sample16.hwp` (HWP 3.0) | `0097.formatted.hwp` |
| `issue5169_viewtext_changetracking.hwp` | `0136.formatted.hwp` |

So applying character and paragraph formatting added no failures in the viewer. The
viewer only opens the files here; whether it shows the formatting as rhwp does was not
compared.

`results.jsonl`: one line per file as printed by the tool.
