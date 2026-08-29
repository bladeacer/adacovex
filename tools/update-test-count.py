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

The file set is derived from the tree (tools/live_files.py) rather than a
hardcoded list, so a new doc file carrying a test count is picked up
automatically and can never go stale.

Usage:
  python3 tools/update-test-count.py [--dry-run] [--check] [--result=docs/test_result.md]

--result   Path to the test-result summary to parse (default
           docs/test_result.md).
--dry-run  Parse and report the new counts without editing any file.
--check    Verify every live file already carries the current counts;
           exit 1 (without editing) when any file is stale.

Exit code 0 when every anchored pattern matched and was updated (or, with
--dry-run/--check, would be / already is), 1 when the result could not be
parsed or a pattern did not match.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

from live_files import live_files  # noqa: E402  (same-tools import)

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
    "Man page renderer": "src/tests/adacovex_man_tests",
    "VCS support": "src/tests/adacovex_vcs_tests",
    "Server routing": "src/tests/adacovex_server_tests",
    "Proof patches": "src/tests/adacovex_prove_patch_tests",
    "Timezone + ANSI": "src/tests/adacovex_tz_ansi_tests",
    "Complexity check": "src/tests/adacovex_complexity_tests",
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
            r"\|\s*([A-Za-z /+\-]+?)\s*\|\s*(\d+)\s*\|", line
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


def total_phrase_repls(passed: int, failed: int, total: int) -> List[Tuple[str, str]]:
    """Anchored (pattern, format) pairs for the total/passed counts."""
    return [
        (r"(\d+)/(\d+) native tests passing", f"{passed}/{total} native tests passing"),
        (r"(\d+)/(\d+) passing", f"{passed}/{total} passing"),
        (r"--require-tests=(\d+)", f"--require-tests={passed}"),
        (r"require-tests: (\d+)", f"require-tests: {passed}"),
        (r"(\d+)-test native suite", f"{total}-test native suite"),
        (r"native test suite \((\d+) tests\)", f"native test suite ({total} tests)"),
        (r"(\d+) tests across \d+ categories",
         f"{total} tests across {len(CATEGORY_KEY)} categories"),
        # JSON API sample response in README / cli-reference.
        (r'"tests_passed":\d+', f'"tests_passed":{passed}'),
        (r'"tests_failed":\d+', f'"tests_failed":{failed}'),
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


def map_lines(cats: Dict[str, int], total: int) -> List[str]:
    """Return the updated tools/agents-tree.map lines (without writing)."""
    path: Path = ROOT / "tools" / "agents-tree.map"
    lines: List[str] = path.read_text().splitlines()
    for i, line in enumerate(lines):
        key: str = line.partition("\t")[0]
        if key == TEST_RUNNER_KEY:
            lines[i], _ = re.subn(r"\((\d+) tests\)", f"({total} tests)", line)
        elif key in CATEGORY_KEY.values():
            for name, k in CATEGORY_KEY.items():
                if k == key:
                    lines[i], _ = re.subn(r"\((\d+)\)$", f"({cats[name]})", line)
                    break
    return lines


def update_map(cats: Dict[str, int], total: int) -> None:
    """Write the per-file counts into tools/agents-tree.map."""
    path: Path = ROOT / "tools" / "agents-tree.map"
    lines: List[str] = map_lines(cats, total)
    path.write_text("\n".join(lines) + "\n")


BEGIN_TREE: str = "<!-- agents-tree:begin -->"
END_TREE: str = "<!-- agents-tree:end -->"


def agents_tree_block() -> str:
    """Return the spliced block (markers + fenced tree) for the current map."""
    gen: Path = ROOT / "tools" / "gen-agents-tree.py"
    proc: subprocess.CompletedProcess = subprocess.run(
        [sys.executable, str(gen)], cwd=str(ROOT), capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise SystemExit(f"gen-agents-tree.py failed:\n{proc.stderr}")
    tree: str = proc.stdout.rstrip()
    return (BEGIN_TREE + "\n```\n" + tree + "\n```\n" + END_TREE)


def regen_agents_tree(check: bool = False) -> bool:
    """Regenerate the AGENTS.md source tree from tools/agents-tree.map.

    Only the fenced block between the agents-tree markers is touched -- the
    rest of AGENTS.md is preserved.  Returns True when the tree is up to
    date (check mode) or was updated.
    """
    agents: Path = ROOT / "AGENTS.md"
    text: str = agents.read_text()
    if BEGIN_TREE not in text or END_TREE not in text:
        raise SystemExit(
            f"error: AGENTS.md is missing the agents-tree markers"
        )
    start: int = text.index(BEGIN_TREE)
    end: int = text.index(END_TREE) + len(END_TREE)
    block: str = agents_tree_block()
    if check:
        return text[start:end] == block
    if text[start:end] != block:
        agents.write_text(text[:start] + block + text[end:])
    return True


def main() -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--result", default=str(ROOT / "docs" / "test_result.md"))
    ap.add_argument("--dry-run", action="store_true",
                    help="report new counts without editing files")
    ap.add_argument("--check", action="store_true",
                    help="verify live files carry the current counts (exit 1 when stale)")
    args: argparse.Namespace = ap.parse_args()

    cats, passed, failed = parse_result(Path(args.result))
    total: int = passed + failed
    print(f"tests: {passed} passed, {failed} failed ({total} total)")
    for name, count in cats.items():
        print(f"  {name}: {count}")

    if args.dry_run:
        return 0

    repls: List[Tuple[str, str]] = total_phrase_repls(passed, failed, total)

    # Every live file under the tree (see tools/live_files.py).  This covers
    # AGENTS.md, README.md, the manifests, the canonical description, the
    # Makefile, the CI workflows, and every docs page that carries a count.
    files: List[Path] = live_files()

    stale: int = 0
    matched: int = 0
    for f in files:
        text: str = f.read_text(errors="replace")
        orig: str = text
        for pat, rep in repls:
            text, n = re.subn(pat, rep, text)
            matched += n
        if text != orig:
            if args.check:
                stale += 1
                print(f"STALE: {f.relative_to(ROOT)}")
            else:
                f.write_text(text)
                print(f"updated: {f.relative_to(ROOT)}")

    # CONTRIBUTING.md category table + total (only file with a per-category
    # table, handled separately from the anchored phrase scan).
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
            if args.check:
                stale += 1
                print(f"STALE: {contrib.relative_to(ROOT)}")
            else:
                contrib.write_text(text)

    # tools/agents-tree.map lives under tools/ (excluded from the generic
    # scan) and carries per-file counts; keep it in sync separately.
    map_orig: str = (ROOT / "tools" / "agents-tree.map").read_text()
    map_new: str = "\n".join(map_lines(cats, total)) + "\n"
    if map_new != map_orig:
        if args.check:
            stale += 1
            print("STALE: tools/agents-tree.map")
        else:
            (ROOT / "tools" / "agents-tree.map").write_text(map_new)

    if args.check:
        # AGENTS.md embeds the source tree; verify it matches the map too.
        if not regen_agents_tree(check=True):
            stale += 1
            print("STALE: AGENTS.md source tree")
        if stale:
            print(f"error: {stale} file(s) carry stale test counts "
                  f"(run `make test-count` to refresh)", file=sys.stderr)
            return 1
        print("test counts in sync across all live files")
        return 0

    update_map(cats, total)
    regen_agents_tree()

    if matched == 0:
        print("error: no test-count pattern matched; docs may be out of sync",
              file=sys.stderr)
        return 1
    print(f"updated {matched} test-count occurrence(s); AGENTS.md tree regenerated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
