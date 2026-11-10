#!/usr/bin/env python3
"""Count docs/web-editor-parity.md against rhwp-studio's command list.

Every rhwp-studio command id must have exactly one status: done (됨), partial
(부분) or not yet (아직). The statuses live in STATUS below, next to the
command ids; this prints the per-group table for the document and fails if a
command is missing, unknown or listed twice.

usage: parity-count.py
"""

import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = [("편집", "edit"), ("파일", "file"), ("서식", "format"), ("입력", "insert"), ("쪽", "page"),
          ("표", "table"), ("하이퍼링크", "hyperlink"), ("보기", "view"), ("도구", "tool")]

PARTIAL = {
    "file:print-to-pdf", "insert:picture-props", "insert:textbox", "table:cell-merge", "table:border-one",
    "table:border-each", "tool:options", "format:object-properties", "table:caption-toggle", "insert:caption-toggle",
    "view:grid-settings",
}
NOT_YET = {
    "edit:compare-documents", "edit:document-history", "field:edit",
    "format:style-dialog", "format:para-num-shape", "format:bullet-shape",
    "insert:equation", "insert:chart-data-edit", "insert:equation-edit",
    "insert:note-close", "insert:field",
    "page:headerfooter-close", "page:headerfooter-prev", "page:headerfooter-next",
    "table:transpose-copy", "table:transpose-paste", "table:cell-height-equal",
    "table:cell-width-equal",
    "view:form-mode",
}


def main():
    studio = ROOT / "third_party/rhwp/rhwp-studio/src/command/commands"
    counts = {}
    seen = Counter()
    for label, group in GROUPS:
        ids = re.findall(r"id:\s*'([a-z:-]+)'", (studio / f"{group}.ts").read_text())
        seen.update(ids)
        tally = Counter("partial" if i in PARTIAL else "not yet" if i in NOT_YET else "done" for i in ids)
        counts[label] = (tally["done"], tally["partial"], tally["not yet"], len(ids))
    unknown = (PARTIAL | NOT_YET) - set(seen)
    twice = [i for i, n in seen.items() if n > 1]
    if unknown or twice:
        sys.exit(f"unknown: {sorted(unknown)} listed twice: {twice}")
    print("| 묶음 | 됨 | 부분 | 아직 | 계 |\n| --- | ---: | ---: | ---: | ---: |")
    for label, (done, partial, not_yet, total) in counts.items():
        print(f"| {label} | {done} | {partial} | {not_yet} | {total} |")
    totals = [sum(column) for column in zip(*counts.values())]
    print("| **합계** | " + " | ".join(f"**{n}**" for n in totals) + " |")


if __name__ == "__main__":
    main()
