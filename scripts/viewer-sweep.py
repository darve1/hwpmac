#!/usr/bin/env python3
"""Open every file of an oracle bundle in Hancom Office HWP Viewer (criterion 3).

Runs hwpmac-viewer-check on each document's original and its four saves
(unedited/edited x HWP/HWPX) and appends one JSON line per file; already
checked files are skipped. Then summarises: among documents whose original
the viewer opens, how many saved files it also opens.

usage: viewer-sweep.py run <viewer-check-binary> <bundle-dir> <results.jsonl>
       viewer-sweep.py summary <bundle-dir> <results.jsonl>
"""

import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

VARIANTS = ["orig", "base.hwp", "base.hwpx", "edited.hwp", "edited.hwpx"]


def files_for(bundle, docid):
    originals = sorted(bundle.glob(f"{docid}.orig.*"))
    return [originals[0]] + [bundle / f"{docid}.{name}" for name in VARIANTS[1:]] if originals else []


def run(tool, bundle, results):
    documents = json.loads((bundle / "documents.json").read_text(encoding="utf-8"))
    done = {json.loads(line)["file"] for line in results.read_text().splitlines()} if results.exists() else set()
    with results.open("a") as sink:
        for docid in sorted(documents):
            pending = [str(path) for path in files_for(bundle, docid) if path.name not in done]
            if not pending:
                continue
            out = subprocess.run([tool, *pending], capture_output=True, text=True, timeout=600)
            for line in out.stdout.splitlines():
                sink.write(line + "\n")
            sink.flush()


def summary(bundle, results):
    documents = json.loads((bundle / "documents.json").read_text(encoding="utf-8"))
    rows = {json.loads(line)["file"]: json.loads(line) for line in results.read_text().splitlines()}
    counts, failures = Counter(), []
    for docid, name in sorted(documents.items()):
        files = files_for(bundle, docid)
        if not files or files[0].name not in rows:
            counts["not checked"] += 1
            continue
        if not rows[files[0].name]["opened"]:
            counts["original not opened by viewer (excluded)"] += 1
            continue
        counts["documents"] += 1
        for variant, path in zip(VARIANTS[1:], files[1:]):
            row = rows.get(path.name)
            if row is None:
                counts[f"{variant}: not checked"] += 1
            elif row["opened"]:
                counts[f"{variant}: opened"] += 1
            else:
                counts[f"{variant}: NOT opened"] += 1
                failures.append({"document": name, "file": path.name, "windows": row["windowTitles"],
                                 "dialog": row["dialog"]})
    print(json.dumps({"summary": dict(sorted(counts.items())), "failures": failures}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "run":
        run(sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4]))
    elif len(sys.argv) == 4 and sys.argv[1] == "summary":
        summary(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        sys.exit(__doc__)
