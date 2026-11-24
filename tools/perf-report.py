#!/usr/bin/env python3
"""Measure adacovex and write the current figures into `docs/stats/`.

`just perf-report` is the release-time measurement task: it runs the scenario
set in `tools/bench.py` (the single owner of the measurement recipe), then
rewrites the generated table on each stats page between its
`<!-- perf-report:begin -->` and `<!-- perf-report:end -->` markers.  The
prose above and below the markers is hand-written and is never touched.

    python3 tools/perf-report.py                 measure, then write the pages
    python3 tools/perf-report.py --check         verify the markers and the
                                                 saved raw report only
    python3 tools/perf-report.py --data=PATH     render a saved raw report
    python3 tools/perf-report.py --out=DIR       write the pages elsewhere

The raw measurement is kept under `obj/perf-report/latest.json`; the pages
carry the summary, so no number is ever edited by hand.  A page states the
version, the host profile, the command, and the mean beside each figure.

Exit code 0 when the report was written (or the check passed), 1 when a page
is missing its markers or the raw report cannot be read.
"""

import argparse
import datetime
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

ROOT: Path = Path(__file__).resolve().parent.parent

sys.path.insert(0, str(ROOT / "tools"))
import bench  # noqa: E402  (same-directory helper, owns the recipe)

BEGIN: str = "<!-- perf-report:begin -->"
END: str = "<!-- perf-report:end -->"
RAW: Path = ROOT / "obj" / "perf-report" / "latest.json"


def fmt_seconds(value: Optional[float]) -> str:
    """Format a duration in seconds for a table cell (ASCII only)."""
    if value is None:
        return "not measured"
    if value >= 10.0:
        return f"{value:.1f} s"
    if value >= 1.0:
        return f"{value:.2f} s"
    return f"{value * 1000.0:.1f} ms"


def fmt_bytes(value: Optional[int]) -> str:
    """Format a byte count for a table cell."""
    if value is None:
        return "not measured"
    for unit, scale in (("MiB", 1048576.0), ("KiB", 1024.0)):
        if value >= scale:
            return f"{value / scale:.1f} {unit} ({value} bytes)"
    return f"{value} bytes"


def report_date(report: Dict) -> str:
    """The date the report names: SOURCE_DATE_EPOCH when set, else today."""
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if epoch and epoch.isdigit():
        moment = datetime.datetime.fromtimestamp(int(epoch),
                                                 datetime.timezone.utc)
    else:
        moment = datetime.datetime.now(datetime.timezone.utc)
    return moment.strftime("%Y-%m-%d")


def scenario_rows(report: Dict) -> List[Dict]:
    """The measured scenarios, in the recipe's order."""
    return list(report.get("scenarios") or [])


def row_by_label(report: Dict, label: str) -> Optional[Dict]:
    """One measured scenario by its label, or None when it did not run."""
    for row in scenario_rows(report):
        if row.get("label") == label:
            return row
    return None


def host_table(report: Dict) -> List[str]:
    """The host profile as a Markdown table."""
    host = report.get("host") or {}
    rows = [
        ("CPU", host.get("cpu", "unknown")),
        ("Cores", str(host.get("cores", 0))),
        ("Kernel", host.get("kernel", "unknown")),
        ("Platform", host.get("platform", "unknown")),
        ("Filesystem", host.get("filesystem", "unknown")),
        ("Compiler", host.get("compiler", "unknown")),
        ("gnatprove", host.get("gnatprove", "unknown")),
        ("Build profile", host.get("build_profile", "unknown")),
        ("hyperfine", host.get("hyperfine", "unknown")),
        ("strace", host.get("strace", "unknown")),
        ("Load average (1 min)", host.get("load_average", "unknown")),
    ]
    lines = ["| Item | Value |", "|------|-------|"]
    for name, value in rows:
        lines.append(f"| {name} | `{value}` |")
    return lines


def header_lines(report: Dict) -> List[str]:
    """The version/date line every generated block opens with."""
    return [
        f"Measured on adacovex `{report.get('version', 'unknown')}` "
        f"on {report_date(report)}.",
        "",
    ]


def timings_block(report: Dict) -> List[str]:
    """The pipeline, prove, build, and docs timing table."""
    lines = header_lines(report)
    lines += ["| Scenario | Mean | Std. dev. | Runs | Command |",
              "|----------|------|-----------|------|---------|"]
    for row in scenario_rows(report):
        stddev = row.get("stddev_s")
        sigma = fmt_seconds(stddev) if stddev is not None else "n/a"
        lines.append(
            f"| {row.get('label', 'unknown')} | "
            f"{fmt_seconds(row.get('mean_s'))} | {sigma} | "
            f"{row.get('runs', 0)} | `{row.get('command', '')}` |")
    tools = sorted({row.get("tool", "unknown") for row in scenario_rows(report)})
    if tools:
        lines += ["", f"Measured with: {', '.join(tools)}."]
    return lines


def binary_block(report: Dict) -> List[str]:
    """The binary-size table."""
    binary = report.get("binary") or {}
    raw, stripped = binary.get("raw"), binary.get("stripped")
    lines = header_lines(report)
    lines += ["| Shape | Size |", "|-------|------|",
              f"| `bin/adacovex` | {fmt_bytes(raw)} |",
              f"| after `strip` | {fmt_bytes(stripped)} |"]
    if raw and stripped:
        saved = 100.0 * (raw - stripped) / raw
        lines.append(f"| stripped saving | {saved:.1f}% |")
    return lines


def syscalls_block(report: Dict) -> List[str]:
    """The strace syscall-count table for one warm pipeline run."""
    lines = header_lines(report)
    readings = report.get("syscalls") or []
    if not readings:
        lines.append("No syscall profile: `strace` is not installed on this "
                     "host.")
        return lines
    lines += ["| Syscall | Calls |", "|---------|-------|"]
    for reading in readings:
        lines.append(f"| `{reading.get('syscall', 'unknown')}` | "
                     f"{reading.get('calls', 0)} |")
    return lines


def cache_block(report: Dict) -> List[str]:
    """The cache hit, miss, and evicted counts of one warm pipeline run."""
    cache = report.get("cache") or {}
    hits = int(cache.get("hits", 0))
    misses = int(cache.get("misses", 0))
    total = hits + misses
    rate = f"{100.0 * hits / total:.1f}%" if total else "n/a"
    lines = header_lines(report)
    lines += ["| Reading | Count |", "|---------|-------|",
              f"| cache hits | {hits} |",
              f"| cache misses | {misses} |",
              f"| evicted entries | {cache.get('evicted', 0)} |",
              f"| hit rate | {rate} |"]
    note = cache.get("note")
    if note:
        lines += ["", note]
    return lines


def bundle_block(report: Dict) -> List[str]:
    """The bundled-manual size and fingerprint table."""
    docs = report.get("docs") or {}
    lines = header_lines(report)
    lines += ["| Reading | Value |", "|---------|-------|",
              f"| spec size | {fmt_bytes(docs.get('spec_bytes'))} |",
              f"| bundled assets | {docs.get('assets', 0)} |",
              f"| source fingerprint | `{docs.get('fingerprint', 'unknown')}` |"]
    for label in ("docs cold tree", "docs fresh"):
        row = row_by_label(report, label)
        if row is not None:
            lines.append(f"| {label} | {fmt_seconds(row.get('mean_s'))} |")
    return lines


def tests_block(report: Dict) -> List[str]:
    """The native test counts the report was measured beside."""
    tests = report.get("tests") or {}
    lines = header_lines(report)
    lines += ["| Reading | Count |", "|---------|-------|",
              f"| native tests passed | {tests.get('passed', 0)} |",
              f"| native tests failed | {tests.get('failed', 0)} |"]
    return lines


def overview_block(report: Dict) -> List[str]:
    """The at-a-glance table and the host profile on the stats index."""
    lines = header_lines(report)
    lines += ["| Metric family | Current value | Detail |",
              "|---------------|---------------|--------|"]
    pipeline_warm = row_by_label(report, "pipeline warm")
    pipeline_cold = row_by_label(report, "pipeline cold")
    prove_warm = row_by_label(report, "prove warm")
    build_warm = row_by_label(report, "build warm")
    binary = report.get("binary") or {}
    docs = report.get("docs") or {}
    cache = report.get("cache") or {}
    tests = report.get("tests") or {}
    lines += [
        f"| Pipeline warm | "
        f"{fmt_seconds((pipeline_warm or {}).get('mean_s'))} | "
        f"[Timings](timings.md) |",
        f"| Pipeline cold | "
        f"{fmt_seconds((pipeline_cold or {}).get('mean_s'))} | "
        f"[Timings](timings.md) |",
        f"| Prove warm | {fmt_seconds((prove_warm or {}).get('mean_s'))} | "
        f"[Timings](timings.md) |",
        f"| Build warm (`alr build`, no-op) | "
        f"{fmt_seconds((build_warm or {}).get('mean_s'))} | "
        f"[Timings](timings.md) |",
        f"| Binary size | {fmt_bytes(binary.get('raw'))} | "
        f"[Binary size](binary-size.md) |",
        f"| Bundled manual spec | {fmt_bytes(docs.get('spec_bytes'))} | "
        f"[Docs bundle](bundle.md) |",
        f"| Cache hits (warm run) | {cache.get('hits', 0)} | "
        f"[Cache](cache.md) |",
        f"| Native tests | {tests.get('passed', 0)} passed | "
        f"[Tests](tests.md) |",
        "",
        "## Host profile",
        "",
    ]
    lines += host_table(report)
    return lines


#  Page file name -> (heading, generated block renderer).  The heading is
#  what `docs-tree` reads, so it matches the page's own H1.
PAGES: Dict[str, str] = {
    "index.md": "overview",
    "timings.md": "timings",
    "binary-size.md": "binary",
    "syscalls.md": "syscalls",
    "cache.md": "cache",
    "bundle.md": "bundle",
    "tests.md": "tests",
}

RENDERERS = {
    "overview": overview_block,
    "timings": timings_block,
    "binary": binary_block,
    "syscalls": syscalls_block,
    "cache": cache_block,
    "bundle": bundle_block,
    "tests": tests_block,
}


def replace_block(text: str, block: List[str]) -> str:
    """Replace the generated region between the markers, or append one.

    The prose around the region belongs to the page's author; only the marked
    region is rewritten, so a hand-written explanation survives a refresh.
    """
    generated = "\n".join([BEGIN] + block + [END])
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end < start:
        if not text.endswith("\n"):
            text += "\n"
        return text + "\n" + generated + "\n"
    return text[:start] + generated + text[end + len(END):]


def load_page(path: Path, title: str, intro: str) -> str:
    """Read a stats page, or create it with its title, intro, and markers."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return f"# {title}\n\n{intro}\n"


def write_page(path: Path, text: str) -> bool:
    """Write a page only when its bytes changed, so a no-op keeps mtimes."""
    try:
        if path.read_text(encoding="utf-8") == text:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")
    return True


def render_pages(report: Dict, out_dir: Path) -> int:
    """Rewrite the generated block of every stats page; return the count."""
    changed = 0
    for name, renderer in PAGES.items():
        path = out_dir / name
        title = {
            "index.md": "Measured figures",
            "timings.md": "Pipeline, prove, build, and docs timings",
            "binary-size.md": "Binary size",
            "syscalls.md": "Syscall profile",
            "cache.md": "Result-cache hit rate",
            "bundle.md": "Docs bundle size and cost",
            "tests.md": "Native test counts",
        }[name]
        existing = load_page(path, title, "Measured output of `just "
                             "perf-report`; the method is on "
                             "[Benchmarking adacovex](../contributing/perf/"
                             "benchmarks.md).")
        text = replace_block(existing, RENDERERS[renderer](report))
        if write_page(path, text):
            changed += 1
    return changed


def check_pages(out_dir: Path) -> List[str]:
    """Report every stats page that has no generated region."""
    problems: List[str] = []
    for name in PAGES:
        path = out_dir / name
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            problems.append(f"{name}: missing")
            continue
        if BEGIN not in text or END not in text:
            problems.append(f"{name}: no perf-report markers")
    return problems


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify the pages and the raw report, no writes")
    parser.add_argument("--data", default=None,
                        help="render a saved raw report instead of measuring")
    parser.add_argument("--out", default=str(ROOT / "docs" / "stats"),
                        help="directory to write the pages into")
    parser.add_argument("--release", action="store_true",
                        help="measure the release profile (alr build "
                             "--release is a no-op on a built tree)")
    parser.add_argument("--version", default="",
                        help="version the report names (default: the dev "
                             "manifest)")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    out_dir = Path(args.out)
    if args.data:
        try:
            report = json.loads(Path(args.data).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"error: cannot read the raw report: {exc}", file=sys.stderr)
            return 1
    elif args.check:
        problems = check_pages(out_dir)
        if RAW.is_file():
            try:
                json.loads(RAW.read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                problems.append(f"{RAW.relative_to(ROOT)}: {exc}")
        for problem in problems:
            print(f"STALE: {problem}")
        return 1 if problems else 0
    else:
        report = bench.collect_report(release=args.release,
                                      version=args.version)
        RAW.parent.mkdir(parents=True, exist_ok=True)
        RAW.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    changed = render_pages(report, out_dir)
    print(f"perf report: {len(PAGES)} page(s) considered, {changed} rewritten")
    for name in PAGES:
        print(f"  {out_dir / name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
