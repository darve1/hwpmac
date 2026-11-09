# Text, objects and pages counted by Hancom's viewer — 2026-11-10

Oracle: 한컴오피스 한글 Viewer 12.31.9 for macOS, its 파일 > 문서 정보… > 문서 통계
(characters with and without spaces, paragraphs, pages, tables/pictures/text boxes).
Every number below is the viewer's own count of the original and of the saves, so
the comparison does not depend on rhwp's text extraction or layout.

Sample: 60 documents drawn with seed 20261110 from the 316 whose original the
viewer opens (`scripts/viewer-sweep.py stats`). Reading the statistics needs the
viewer in front, so the run was limited to a sample.

## Text and objects (criterion 4)

Unedited saves must match the original exactly; edited saves must differ by the
edit script's text only: +9 characters with spaces, +8 without, +1 paragraph,
no objects.

| Save | As expected |
| --- | --- |
| Unedited HWP | 57 / 57 |
| Unedited HWPX | 57 / 57 |
| Edited HWP | 56 / 56 |
| Edited HWPX | 55 / 55 |

225 of 225 readable saves: no lost or extra characters, paragraphs or objects as
the viewer counts them. Statistics could not be read for 3 originals and 3 edited
saves (the dialog did not open in time); those are left out.

## Pages (criterion 5)

| Save | Same page count as the original |
| --- | --- |
| Unedited HWP | 57 / 57 |
| Unedited HWPX | 56 / 57 |
| Edited HWP | 51 / 56 |
| Edited HWPX | 51 / 55 |

The unedited mismatch is `hwp3-sample11.hwp` saved as HWPX (+1 page), again an
HWP 3.0 original. Every edited mismatch is +1 page: the edit adds a paragraph,
which can push content onto a new page, so these are expected.

## Limits

- One Hancom product, the macOS viewer, whose pagination differs from the Windows
  editor for some documents (rhwp's notes: 37 vs 35 pages for one sample; the viewer
  gives 37 here too).
- Counts, not character-by-character text; a substitution that keeps counts equal
  would pass.
- A 60-document sample of rhwp's sample set.
