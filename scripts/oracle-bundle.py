#!/usr/bin/env python3
"""Package edit-sweep output for checking in real 한글, and judge the results.

Criteria 3 and 4 need 한글 itself. rhwp ships a Windows harness that opens
files in 한글 2018/2022/2024 over COM and records, per file, whether it opened
and 한글's own text, page count and control count
(third_party/rhwp/tools/loadsave_sweep/oracle_run.ps1).

bundle: copies each document's original and the four files hwpmac-edit-check
saved (unedited and edited, HWP and HWPX) into one folder with plain names, and
writes oracle_tasks.tsv (key TAB Windows path) for oracle_run.ps1.

    oracle-bundle.py bundle <edit-check-dir> <inputs.list0> <bundle-dir> <windows-dir>

Then on Windows, with 한글 installed, from the rhwp checkout:

    powershell -NoProfile -ExecutionPolicy Bypass -File tools\\loadsave_sweep\\oracle_run.ps1 `
      -HwpVersion 2022 -TaskPath <windows-dir>\\oracle_tasks.tsv -OutDir <windows-dir>\\oracle_2022 -HideWindow

judge: reads oracle_run.ps1's result.tsv and checks, per document:
  - every saved file opens in 한글                         (criterion 3)
  - the unedited saves keep 한글's text length and controls (criterion 4, CER 0 proxy)
  - the edited saves differ from the unedited ones only by the inserted text

    oracle-bundle.py judge <bundle-dir> <result.tsv>
"""

import json
import shutil
import sys
from collections import defaultdict
from pathlib import Path, PureWindowsPath

SAVED = ["base.hwp", "base.hwpx", "edited.hwp", "edited.hwpx"]
# "[편집]각" + "새 문단" + one paragraph break, as 한글 counts text.
INSERTED_CHARACTERS = range(9, 12)


def find_saved(edit_check_dir, index):
    for pattern in (f"out/{index:04d}.{{}}", f"out/{index:04d}/0000.{{}}"):
        files = {name: edit_check_dir / pattern.format(name) for name in SAVED}
        if all(path.exists() for path in files.values()):
            return files
    return None


def bundle(edit_check_dir, inputs_list, bundle_dir, windows_dir):
    inputs = [p.decode() for p in inputs_list.read_bytes().split(b"\0") if p]
    bundle_dir.mkdir(parents=True, exist_ok=True)
    tasks, documents = [], {}
    for index, source in enumerate(inputs):
        saved = find_saved(edit_check_dir, index)
        if saved is None:
            continue
        docid = f"{index:04d}"
        names = {"orig": f"{docid}.orig{Path(source).suffix.lower()}"}
        shutil.copyfile(source, bundle_dir / names["orig"])
        for name, path in saved.items():
            key = name.replace(".", "_")
            names[key] = f"{docid}.{name}"
            shutil.copyfile(path, bundle_dir / names[key])
        for key, name in names.items():
            tasks.append(f"{docid}.{key}\t{PureWindowsPath(windows_dir, name)}")
        documents[docid] = Path(source).name
    (bundle_dir / "oracle_tasks.tsv").write_text("\n".join(tasks) + "\n", encoding="utf-8")
    (bundle_dir / "documents.json").write_text(json.dumps(documents, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(documents)} documents, {len(tasks)} files -> {bundle_dir}")


def judge(bundle_dir, result_tsv):
    documents = json.loads((bundle_dir / "documents.json").read_text(encoding="utf-8"))
    rows = defaultdict(dict)
    for line in result_tsv.read_text(encoding="utf-8-sig").splitlines():
        cells = line.split("\t")
        if len(cells) < 8:
            continue
        key, status, pages, text_len, _sha, ctrls, _bytes, error = cells[:8]
        docid, variant = key.split(".", 1)
        rows[docid][variant] = {"status": status, "pages": int(pages), "textLen": int(text_len),
                                "ctrls": ctrls, "error": error}

    summary = defaultdict(int)
    problems = []
    for docid, name in documents.items():
        measured = rows.get(docid, {})
        if not measured:
            summary["not measured"] += 1
            continue
        if measured.get("orig", {}).get("status") != "OK":
            summary["original does not open in 한글"] += 1
            continue
        summary["documents"] += 1
        orig = measured["orig"]
        for variant in ("base_hwp", "base_hwpx", "edited_hwp", "edited_hwpx"):
            row = measured.get(variant)
            if row is None or row["status"] != "OK":
                summary[f"{variant}: does not open"] += 1
                problems.append({"document": name, "file": variant, "error": (row or {}).get("error", "missing")})
                continue
            summary[f"{variant}: opens"] += 1
            if variant.startswith("base"):
                same_text = row["textLen"] == orig["textLen"]
                same_ctrls = row["ctrls"] == orig["ctrls"]
                summary[f"{variant}: same text length as original"] += same_text
                summary[f"{variant}: same controls as original"] += same_ctrls
                if not (same_text and same_ctrls):
                    problems.append({"document": name, "file": variant, "textLen": [orig["textLen"], row["textLen"]],
                                     "ctrls": [orig["ctrls"], row["ctrls"]]})
            else:
                base = measured.get(variant.replace("edited", "base"), {})
                delta = row["textLen"] - base.get("textLen", 0)
                ok = delta in INSERTED_CHARACTERS and row["ctrls"] == base.get("ctrls")
                summary[f"{variant}: only the edit changed"] += ok
                if not ok:
                    problems.append({"document": name, "file": variant, "textDelta": delta,
                                     "ctrls": [base.get("ctrls"), row["ctrls"]]})
    print(json.dumps({"summary": dict(summary), "problems": problems}, ensure_ascii=False, indent=1))


def main():
    if len(sys.argv) == 6 and sys.argv[1] == "bundle":
        bundle(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]), sys.argv[5])
    elif len(sys.argv) == 4 and sys.argv[1] == "judge":
        judge(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
