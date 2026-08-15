#!/usr/bin/env python3
"""Update the current test-suite counts in the repo after `make test`.

The test counts in AGENTS.md, README.md, Makefile, the CI workflows,
alire.toml, and tools/agents-tree.map were edited by hand and went stale on
every test change.  This script parses docs/test_result.md (written by
`make test` / test_runner), extracts the per-category counts and the
Passed/Failed totals, and rewrites the anchored test-count phrases across the
repo.  It then updates tools/agents-tree.map and regenerates the AGENTS.md
source tree so the per-file test counts stay in sync.

Historical notes (past-release changelogs, the proof ledger) are left
untouched because they do not match the anchored patterns.  The generated
badge (docs/badges/tests.svg) is *not* edited here: `make run-self` rewrites
it from the assessment, recomputing the width for the live count.

Usage:
  python3 tools/update-test-count.py [--dry-run] [--result=docs/test_result.md]

--result   Path to the test-result summary to parse (default
           docs/test_result.md).
--dry-run  Parse and report the new counts without editing any file.

Exit code 0 when every anchored pattern matched and was updated (or, with
--dry-run, would be), 1 when the result could not be parsed or a pattern did
not match.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

# docs/test_result.md category name -> agents-tree.map file key.
CATEGORY_KEY: Dict[str, str] = {
    "Types conversions": "src/tests/adacovex_types_tests",
    "DAL compliance": "src/tests/adacovex_dal_tests",
    "Source scanner": "src/tests/adacovex_scanner_tests",
    "GNATprove parser": "src/tests/adacovex_prove_tests",
    "Test-result parser": "src/tests/adacovex_testparser_tests",
    "CLI config": "src/tests/adacovex_config_tests",
    "SVG renderer": "src/tests/adacovex_renderer_svg_tests",
    "HTML/Markdown renderers": "src/tests/adacovex_renderer_tests",
    "SBOM generator": "src/tests/adacovex_sbom_tests",
    "IR synthesis": "src/tests/adacovex_ir_tests",
}

TEST_RUNNER_KEY: str = "src/tests/test_runner"


def parse_result(path: Path) -> Tuple[Dict[str, int], int, int]:
    """Return (category counts, passed, failed) from a test_result.md file."""
    text: str = Path(path).read_text(errors="replace")
    cats: Dict[str, int] = {}
    passed: Optional[int] = None
    failed: Optional[int] = None

    for raw in text.splitlines():
        line: str = raw.strip()
        m: Optional[re.Match] = re.match(
            r"\|\s*([A-Za-z /-]+?)\s*\|\s*(\d+)\s*\|", line
        )
        if m:
            name: str = m.group(1).strip()
            if name not in ("Category", "Tests"):
                cats[name] = int(m.group(2))
        m = re.match(r"Passed:\s*(\d+)\s+Failed:\s*(\d+)", line)
        if m:
            passed = int(m.group(1))
            failed = int(m.group(2))

    if passed is None:
        raise SystemExit(f"error: no 'Passed: N  Failed: M' line in {path}")
    if not cats:
        raise SystemExit(f"error: no category rows found in {path}")

    for name in CATEGORY_KEY:
        if name not in cats:
            raise SystemExit(f"error: category '{name}' missing from {path}")
    return cats, passed, failed or 0


def total_phrase_repls(passed: int, total: int) -> List[Tuple[str, str]]:
    """Anchored (pattern, format) pairs for the total/passed counts."""
    return [
        (r"(\d+)/(\d+) native tests passing", f"{passed}/{total} native tests passing"),
        (r"(\d+)/(\d+) passing", f"{passed}/{total} passing"),
        (r"--require-tests=(\d+)", f"--require-tests={passed}"),
        (r"require-tests: (\d+)", f"require-tests: {passed}"),
        (r"(\d+)-test native suite", f"{total}-test native suite"),
        (r"native test suite \((\d+) tests\)", f"native test suite ({total} tests)"),
        (r"(\d+) tests across 10 categories", f"{total} tests across 10 categories"),
    ]


def update_text_file(path: Path, repls: List[Tuple[str, str]]) -> int:
    """Apply regex replacements to a text file; return match count."""
    if not path.exists():
        print(f"skip (missing): {path.name}")
        return 0
    text: str = path.read_text()
    matched: int = 0
    for pat, rep in repls:
        text, n = re.subn(pat, rep, text)
        matched += n
    path.write_text(text)
    return matched


def update_map(cats: Dict[str, int], passed: int, total: int) -> int:
    """Update the per-file counts in tools/agents-tree.map."""
    path: Path = ROOT / "tools" / "agents-tree.map"
    lines: List[str] = path.read_text().splitlines()
    matched: int = 0
    for i, line in enumerate(lines):
        key: str = line.partition("\t")[0]
        if key == TEST_RUNNER_KEY:
            line, n = re.subn(r"\((\d+) tests\)", f"({total} tests)", line)
            matched += n
        elif key in CATEGORY_KEY.values():
            for name, k in CATEGORY_KEY.items():
                if k == key:
                    line, n = re.subn(r"\((\d+)\)$", f"({cats[name]})", line)
                    matched += n
                    break
        lines[i] = line
    path.write_text("\n".join(lines) + "\n")
    return matched


def regen_agents_tree() -> None:
    """Regenerate the AGENTS.md source tree from tools/agents-tree.map."""
    gen: Path = ROOT / "tools" / "gen-agents-tree.py"
    apply_: Path = ROOT / "tools" / "apply-agents-tree.py"
    tmp: Path = ROOT / "tools" / ".agents-tree.tmp"
    proc: subprocess.CompletedProcess = subprocess.run(
        [sys.executable, str(gen)], cwd=str(ROOT), capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise SystemExit(f"gen-agents-tree.py failed:\n{proc.stderr}")
    tmp.write_text(proc.stdout)
    subprocess.run([sys.executable, str(apply_), str(tmp)],
                   cwd=str(ROOT), check=True)
    tmp.unlink()


def main() -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--result", default=str(ROOT / "docs" / "test_result.md"))
    ap.add_argument("--dry-run", action="store_true",
                    help="report new counts without editing files")
    args: argparse.Namespace = ap.parse_args()

    cats, passed, failed = parse_result(Path(args.result))
    total: int = passed + failed
    print(f"tests: {passed} passed, {failed} failed ({total} total)")
    for name, count in cats.items():
        print(f"  {name}: {count}")

    if args.dry_run:
        return 0

    repls: List[Tuple[str, str]] = total_phrase_repls(passed, total)

    text_files: List[Path] = [
        ROOT / "AGENTS.md",
        ROOT / "README.md",
        ROOT / "alire.toml",
        ROOT / "Makefile",
        ROOT / ".github" / "workflows" / "ci.yml",
        ROOT / ".github" / "workflows" / "release.yml",
        ROOT / "docs" / "architecture.md",
        ROOT / "docs" / "cli-reference.md",
    ]

    matched: int = 0
    for f in text_files:
        matched += update_text_file(f, repls)

    # CONTRIBUTING.md category table + total.
    contrib: Path = ROOT / "CONTRIBUTING.md"
    if contrib.exists():
        text: str = contrib.read_text()
        orig: str = text
        for name, count in cats.items():
            text, n = re.subn(
                rf"\|\s*{re.escape(name)}\s*\|\s*\d+\s*\|",
                f"| {name} | {count} |",
                text,
            )
            matched += n
        text, n = re.subn(
            r"\|\s*\*\*Total\*\*\s*\|\s*\*\*\d+\*\*\s*\|",
            f"| **Total** | **{total}** |",
            text,
        )
        matched += n
        if text != orig:
            contrib.write_text(text)

    matched += update_map(cats, passed, total)
    regen_agents_tree()

    if matched == 0:
        print("error: no test-count pattern matched; docs may be out of sync",
              file=sys.stderr)
        return 1
    print(f"updated {matched} test-count occurrence(s); AGENTS.md tree regenerated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
