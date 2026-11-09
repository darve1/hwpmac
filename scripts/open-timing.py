#!/usr/bin/env python3
"""Measure document open time (criterion S) with hwpmac-render-snapshot.

Opens every document with at least <min-pages> pages <runs> times (one
process each, so caches do not carry over) and reports per-document and
pooled p50/p95 of `openSeconds` as JSON.

usage: open-timing.py <render-snapshot-binary> <edit-sweep-results.jsonl> <samples-dir> <min-pages> <runs>
"""

import json
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path


def percentile(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(len(ordered) * q))]


def main():
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    tool, results, samples, min_pages, runs = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    large = {row["input"] for row in map(json.loads, results.read_text().splitlines())
             if row.get("pageCount", 0) >= min_pages}
    files = [p for p in sorted(samples.iterdir()) if unicodedata.normalize("NFC", p.name) in large]
    report, pooled = [], []
    with tempfile.TemporaryDirectory() as scratch:
        for path in files:
            times = []
            for _ in range(runs):
                out = subprocess.run([tool, str(path), "0", "1", str(Path(scratch) / "page.png")],
                                     capture_output=True, text=True, timeout=600)
                summary = json.loads(out.stdout)
                times.append(summary["openSeconds"])
            pooled += times
            report.append({"input": unicodedata.normalize("NFC", path.name), "pages": summary["pageCount"],
                           "p50": percentile(times, 0.5), "max": max(times)})
    print(json.dumps({"documents": len(files), "runsEach": runs, "pooledP50": percentile(pooled, 0.5),
                      "pooledP95": percentile(pooled, 0.95), "perDocument": report}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
