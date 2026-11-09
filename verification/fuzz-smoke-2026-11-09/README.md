# Fuzz smoke — 2026-11-09

rhwp's own cargo-fuzz harnesses (`third_party/rhwp/fuzz`, rhwp v0.9.0) on this Mac
(Apple M5, nightly Rust, libFuzzer with AddressSanitizer), seeded with rhwp's corpus
for each target, flags as rhwp recommends:

```sh
cargo +nightly fuzz run <target> <out-corpus> fuzz/corpus/<target> -- \
  -rss_limit_mb=2048 -timeout=30 -max_total_time=900
```

| Target | Runs | Speed | Coverage start → end | New units | Peak RSS | Crashes / OOM / timeouts |
| --- | --- | --- | --- | --- | --- | --- |
| `parse_hwp` (HWP 5.x, CFB) | 718,918 | 797/s | 6,209 → 9,039 | 3,795 | 1,040 MB | 0 |
| `parse_hwpx` (HWPX, ZIP/XML) | 573,452 | 636/s | 13,900 → 15,206 | 3,373 | 819 MB | 0 |

Coverage was still rising at the end of both runs, so neither reached a plateau.

## Against the criterion

T was set as: at least 24 hours per parser target, a coverage plateau, and no sanitizer
findings when replaying the corpus. This run is 15 minutes per target, no plateau. It
shows the harness builds and runs here and found nothing in that time; it does not meet T.

These targets fuzz parsing only. Layout, editing and serialization paths (and rhwp's
`export_svg`, `parse_equation`, WMF and chart targets) were not run. In the app the
parser runs inside the sandboxed EngineService process, which limits what a parser bug
could reach.
