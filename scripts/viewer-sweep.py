#!/usr/bin/env python3
"""Open every file of an oracle bundle in Hancom Office HWP Viewer (criterion 3).

Runs hwpmac-viewer-check on each document's original and its four saves
(unedited/edited x HWP/HWPX) and appends one JSON line per file; already
checked files are skipped. Then summarises: among documents whose original
the viewer opens, how many saved files it also opens.

stats: on a seeded random sample of documents whose original the viewer opens,
records Hancom's 문서 통계 for each file (the viewer comes to the front for each
file) and compares saves with their original: text and objects (criterion 4)
and page count (criterion 5), all as counted by the same viewer.

usage: viewer-sweep.py run <viewer-check-binary> <bundle-dir> <results.jsonl>
       viewer-sweep.py summary <bundle-dir> <results.jsonl>
       viewer-sweep.py stats <viewer-check-binary> <bundle-dir> <results.jsonl> <stats.jsonl> <documents> <seed>
       viewer-sweep.py stats-summary <bundle-dir> <stats.jsonl>
"""

import json
import random
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


TEXT_KEYS = ["글자(공백 포함)", "글자(공백 제외)", "문단", "표, 그림, 글상자"]
# The edit script adds "[편집]각" and a paragraph "새 문단": 9 characters with
# spaces, 8 without, one paragraph, no objects.
EDIT_DELTA = {"글자(공백 포함)": 9, "글자(공백 제외)": 8, "문단": 1, "표, 그림, 글상자": 0}


def stats(tool, bundle, results, out, documents, seed):
    opened = {json.loads(line)["file"] for line in results.read_text().splitlines() if json.loads(line)["opened"]}
    candidates = [docid for docid in sorted(json.loads((bundle / "documents.json").read_text(encoding="utf-8")))
                  if files_for(bundle, docid) and files_for(bundle, docid)[0].name in opened]
    sample = sorted(random.Random(seed).sample(candidates, min(documents, len(candidates))))
    done = {json.loads(line)["file"] for line in out.read_text().splitlines()} if out.exists() else set()
    with out.open("a") as sink:
        for docid in sample:
            pending = [str(path) for path in files_for(bundle, docid) if path.name not in done]
            if pending:
                result = subprocess.run([tool, "--stats", *pending], capture_output=True, text=True, timeout=900)
                sink.write(result.stdout)
                sink.flush()


def stats_summary(bundle, out):
    documents = json.loads((bundle / "documents.json").read_text(encoding="utf-8"))
    rows = {json.loads(line)["file"]: json.loads(line) for line in out.read_text().splitlines()}
    counts, mismatches = Counter(), []
    for docid, name in sorted(documents.items()):
        files = files_for(bundle, docid)
        if not files or files[0].name not in rows:
            continue
        original = rows[files[0].name].get("statistics")
        if not original:
            counts["original statistics unreadable"] += 1
            continue
        counts["documents"] += 1
        found = {variant: (rows.get(path.name) or {}).get("statistics") for variant, path in zip(VARIANTS[1:], files[1:])}
        for variant, measured in found.items():
            if not measured:
                counts[f"{variant}: statistics unreadable"] += 1
                continue
            base = original if variant.startswith("base") else found.get(variant.replace("edited", "base"))
            if not base:
                continue
            expected = {key: base[key] + (EDIT_DELTA[key] if variant.startswith("edited") else 0) for key in TEXT_KEYS}
            text_ok = all(measured[key] == expected[key] for key in TEXT_KEYS)
            pages_ok = measured["쪽"] == original["쪽"]
            counts[f"{variant}: text and objects as expected"] += text_ok
            counts[f"{variant}: same page count as original"] += pages_ok
            if not (text_ok and pages_ok):
                mismatches.append({"document": name, "file": variant,
                                   "delta": {key: measured[key] - base[key] for key in TEXT_KEYS + ["쪽"]},
                                   "expectedDelta": EDIT_DELTA if variant.startswith("edited") else {}})
    print(json.dumps({"summary": dict(sorted(counts.items())), "mismatches": mismatches}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "run":
        run(sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4]))
    elif len(sys.argv) == 4 and sys.argv[1] == "summary":
        summary(Path(sys.argv[2]), Path(sys.argv[3]))
    elif len(sys.argv) == 8 and sys.argv[1] == "stats":
        stats(sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4]), Path(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7]))
    elif len(sys.argv) == 4 and sys.argv[1] == "stats-summary":
        stats_summary(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        sys.exit(__doc__)
