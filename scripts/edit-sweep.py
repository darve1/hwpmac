#!/usr/bin/env python3
"""Run hwpmac-edit-check over a corpus, one process per document.

Each document gets its own process and a time limit, so a document that
hangs or crashes the engine is recorded as such instead of stopping the
sweep. Results are appended as JSON lines; documents already in the results
file are skipped, so an interrupted sweep can be resumed.

usage: edit-sweep.py <edit-check-binary> <output-dir> <timeout-seconds> <input>...
"""

import json
import subprocess
import sys
import time
from pathlib import Path


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    tool, output, timeout = sys.argv[1], Path(sys.argv[2]), float(sys.argv[3])
    inputs = sys.argv[4:]
    output.mkdir(parents=True, exist_ok=True)
    results = output / "results.jsonl"
    done = set()
    if results.exists():
        done = {json.loads(line)["input"] for line in results.read_text().splitlines() if line.strip()}

    with results.open("a") as sink, (output / "stderr.log").open("a") as log:
        for index, path in enumerate(inputs):
            name = Path(path).name
            if name in done:
                continue
            workdir = output / "out" / f"{index:04d}"
            started = time.monotonic()
            try:
                completed = subprocess.run(
                    [tool, str(workdir), path], capture_output=True, text=True, timeout=timeout
                )
                log.write(completed.stderr)
                lines = [line for line in completed.stdout.splitlines() if line.strip()]
                if completed.returncode == 0 and len(lines) == 1:
                    result = json.loads(lines[0])
                else:
                    result = {"input": name, "ok": False, "stage": "process",
                              "error": f"exit code {completed.returncode}"}
            except subprocess.TimeoutExpired:
                result = {"input": name, "ok": False, "stage": "timeout",
                          "error": f"no result within {timeout:.0f}s"}
            result["seconds"] = round(time.monotonic() - started, 2)
            sink.write(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n")
            sink.flush()


if __name__ == "__main__":
    main()
