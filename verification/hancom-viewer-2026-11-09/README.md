# Saved files opened in Hancom Office HWP Viewer — 2026-11-09

Oracle: 한컴오피스 한글 Viewer 12.31.9 for macOS (Mac App Store, Hancom), the
only Hancom software available on this machine.

Input: the oracle bundle from the edit sweep (`scripts/oracle-bundle.py`), 320
documents from rhwp's samples. For each document the original plus the four files
saved through the app's engine path: unedited and edited (the L1 edit script),
each as HWP and HWPX.

Method: `hwpmac-viewer-check` opens each file in the viewer and reads its windows
through the Accessibility API. The viewer shows no error for a file it cannot
parse; it opens a blank "빈 문서" window instead (calibrated with a truncated
.hwp). A file counts as opened only when a window titled after it appears with no
dialog. `scripts/viewer-sweep.py` runs it over the bundle; documents whose original
the viewer does not open are excluded.

## Results

| Saved file | Opened |
| --- | --- |
| Unedited, HWP | 315 / 316 |
| Unedited, HWPX | 316 / 316 |
| Edited, HWP | 314 / 316 |
| Edited, HWPX | 316 / 316 |
| **All** | **1,261 / 1,264 (99.8 %)** |

4 documents were excluded because the viewer does not open their originals.

Failures, all in the HWP output:

| Document | File | Viewer |
| --- | --- | --- |
| `hwp3-sample16.hwp` (HWP 3.0) | unedited HWP, edited HWP | "파일이 손상되었습니다." |
| `issue5169_viewtext_changetracking.hwp` | edited HWP | "손상된 문서의 내용을 복구할까요?" |

The HWPX saves of both documents open. The app now warns before saving an HWP 3.0
document as HWP and suggests HWPX.

## Limits

- One Hancom product: the macOS viewer, not the Windows editor. rhwp's notes show
  Hancom tools differ in layout; this run only checks that files open.
- The viewer exposes no page count or text through Accessibility, so text (criterion
  4) and layout (criterion 5) are not measured here.
- An earlier attempt was invalid: force-quitting the viewer between files made it
  show a "reopen windows after an unexpected quit?" prompt on every later launch,
  and those results were discarded. The checker now quits the viewer normally and
  launches it with `-ApplePersistenceIgnoreState YES`.
