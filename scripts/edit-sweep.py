#!/usr/bin/env python3
"""Run hwpmac-edit-check over a corpus, one process per document.

Each document gets its own process and a time limit, so a document that
hangs or crashes the engine is recorded as such instead of stopping the
sweep. Results are appended as JSON lines; documents already in the results
file are skipped, so an interrupted sweep can be resumed.

--format (L2 formatting check) and --cell (L3 table-cell edit) are passed on
to the tool.

usage: edit-sweep.py [--format | --cell] <edit-check-binary> <output-dir> <timeout-seconds> <input>...
"""

import json
import subprocess
import sys
import time
import unicodedata
from pathlib import Path


def main():
    tool_flags = {"--format", "--cell"}
    flags = [arg for arg in sys.argv[1:] if arg in tool_flags]
    args = [arg for arg in sys.argv[1:] if arg not in tool_flags]
    if len(args) < 4:
        sys.exit(__doc__)
    tool, output, timeout = args[0], Path(args[1]), float(args[2])
    inputs = args[3:]
    output.mkdir(parents=True, exist_ok=True)
    results = output / "results.jsonl"
    done = set()
    if results.exists():
        done = {unicodedata.normalize("NFC", json.loads(line)["input"])
                for line in results.read_text().splitlines() if line.strip()}

    with results.open("a") as sink, (output / "stderr.log").open("a") as log:
        for index, path in enumerate(inputs):
            # macOS file names may be NFD while results hold whatever the tool printed.
            name = unicodedata.normalize("NFC", Path(path).name)
            if name in done:
                continue
            workdir = output / "out" / f"{index:04d}"
            started = time.monotonic()
            try:
                completed = subprocess.run(
                    [tool, *flags, str(workdir), path], capture_output=True, text=True, timeout=timeout
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
