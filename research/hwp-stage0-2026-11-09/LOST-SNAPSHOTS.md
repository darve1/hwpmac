# Lost snapshots (2026-11-09)

The `snapshots/` folder was deleted from disk while removing it from git history
before publishing (a `git filter-branch` checkout removed the files and `git gc`
pruned the old objects). It is now ignored by git, because it holds copies of
third-party papers and pages.

The sources were downloaded again with the ledger helper. 36 of 41 came back
byte-identical to the recorded `sha256` and are restored at their recorded paths.
These 5 could not be restored, because the live content has changed since:

| Source | Why it differs now |
| --- | --- |
| `rhwp-api`, `hop-api` | GitHub repository metadata (stars, push time) |
| `rhwp-rel`, `hop-rel` | GitHub latest-release metadata (download counts) |
| `msrc-office-sdl` | Live web page |

Their quotes in `evidence.jsonl` are what was read at the time, but the preserved
copies behind them are gone, so `check` reports 5 `snapshot_path` errors (6 lines,
one source also lost its extracted text). Treat claims that rely on them
(maintenance status of rhwp and HOP) as checked on 2026-11-09 without a surviving copy.
