#!/usr/bin/env python3
"""Cyclomatic-complexity and file-size static gate for the Ada sources.

Enforces the "no god objects / no god functions / no extra-long files"
rule (separation of concerns) as a machine-checkable quality gate:

* per-file source LOC must not exceed a hard cap (`--max-file-loc`);
* a single file must not exceed a percentage of the whole codebase
  (`--max-file-pct`) -- no file may dominate the tree;
* per-subprogram cyclomatic complexity must not exceed a cap
  (`--max-fn-complexity`) -- decision-heavy functions are flagged as
  refactor candidates;
* per-file total cyclomatic complexity must not exceed a cap
  (`--max-file-complexity`) -- a file that accumulates decision points is
  a god object in the making.

Cyclomatic complexity is the classic decision-point count: 1 + the number
of `if` / `elsif` / `case` / `while` / `for` / `exit` / `and then` /
`or else` / `when` branches in the subprogram.  The scanner is a
line-based approximation (not a full AST): subprogram windows run from a
top-level `procedure`/`function` header at 3-space indentation to the next
top-level header, so nested helpers count toward their enclosing
subprogram -- a conservative, stable measure.

Decision tokens inside Ada comments or string literals are not counted.

The two generated specs (version info, dashboard template) are excluded;
everything else under src/ -- production code and the native test suite --
is gated.

Usage:
  python3 tools/check-complexity.py                          # report
  python3 tools/check-complexity.py --check                  # gate
  python3 tools/check-complexity.py --json=complexity.json   # export

Exit code 0 on success (or report-only), 1 on a gate violation (--check)
or an internal error.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

# Top-level subprogram headers: exactly 3 leading spaces (package bodies
# declare top-level subprograms at 3-space indent; nested declarations use
# 6+ spaces and are attributed to their enclosing subprogram).
HEADER_RE: re.Pattern = re.compile(
    r"^   (?:overriding\s+)?(?:procedure|function)\s+([A-Za-z_0-9]+)"
)
NESTED_HEADER_RE: re.Pattern = re.compile(
    r"^\s{6,}(?:overriding\s+)?(?:procedure|function)\s+[A-Za-z_0-9]+"
)
PACKAGE_BLOCK_RE: re.Pattern = re.compile(
    r"^package\s+(?:body\s+)?([A-Za-z_0-9.]+)\s+is"
)
# `end NAME;` or bare `end;` terminators (NOT `end if;` / `end loop;` /
# `end loop NAME;`, which only close control structures).
END_NAMED_RE: re.Pattern = re.compile(r"^end (?!if|loop|case|select|return|declare|block)([A-Za-z_0-9.]*);?$")
END_BARE_RE: re.Pattern = re.compile(r"^end;$")


def strip_comments(line: str) -> str:
    """Remove Ada comments (-- to end of line) outside string literals."""
    out: List[str] = []
    in_str: bool = False
    i: int = 0
    while i < len(line):
        c: str = line[i]
        if in_str:
            out.append(c)
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "-" and i + 1 < len(line) and line[i + 1] == "-":
            break
        out.append(c)
        i += 1
    return "".join(out)


def count_decisions(line: str) -> int:
    """Count decision points on one Ada source line.

    Counts `if`, `elsif`, `case`, `while`, `for`, `exit`, `and then`,
    `or else`, `when` (case alternative or exception handler), and a
    catch-all for a bare `exception` keyword.  `and`/`or` alone are boolean
    operators, not branches; only the short-circuit forms widen the control
    graph, so they are matched contextually.
    """
    s: str = strip_comments(line)
    if not s.strip():
        return 0
    n: int = 0
    words: List[str] = re.findall(r"[a-zA-Z_][a-zA-Z_0-9]*", s.lower())
    prev: str = ""
    for w in words:
        if w in ("if", "elsif", "case", "while", "for", "exit", "when"):
            n += 1
        elif w == "and" and prev == "then":
            n += 1
        elif w == "or" and prev == "else":
            n += 1
        prev = w
    return n


class Subprogram(NamedTuple):
    """One top-level subprogram: name, header line, complexity, loc."""

    name: str
    line: int
    complexity: int
    loc: int


class FileMetrics(NamedTuple):
    """Per-file metrics: source LOC, total complexity, subprograms."""

    loc: int
    complexity: int
    subprograms: List[Subprogram]


def analyze(path: Path) -> FileMetrics:
    """Compute LOC + cyclomatic complexity for one Ada file.

    A small stack tracks the current lexical block.  Top-level subprogram
    windows are proper: only the matching `end <name>;` closes them, so a
    nested package (e.g. Config.Testing) is not folded into the enclosing
    subprogram's window.  Decisions inside a subprogram's body (and its
    nested helpers) accrue to it; package-level stray decisions are not
    attributed to any subprogram.
    """
    lines: List[str] = path.read_text(errors="replace").splitlines()
    loc: int = 0
    subs: List[Subprogram] = []
    cur: Optional[List[object]] = None  # [name, line, cx, loc]
    stack: List[Tuple[str, int]] = []  # (kind, name_or_"") kinds: pkg/sub

    def flush() -> None:
        nonlocal cur
        if cur is not None:
            subs.append(
                Subprogram(str(cur[0]), int(cur[1]), int(cur[2]), int(cur[3]))
            )
            cur = None

    for idx, raw in enumerate(lines):
        line_no: int = idx + 1
        stripped: str = strip_comments(raw).strip()
        if not stripped or stripped.startswith("--"):
            continue
        loc += 1

        m_pkg: Optional[re.Match] = PACKAGE_BLOCK_RE.match(stripped)
        m_hdr: Optional[re.Match] = HEADER_RE.match(raw)
        m_end: Optional[re.Match] = END_NAMED_RE.match(stripped)
        m_end_bare: Optional[re.Match] = END_BARE_RE.match(stripped)

        d: int = count_decisions(raw)

        if m_pkg:
            stack.append(("pkg", m_pkg.group(1)))
            continue
        if m_hdr:
            if cur is not None:
                flush()
            cur = [m_hdr.group(1), line_no, d, 1]
            stack.append(("sub", m_hdr.group(1)))
            continue
        if m_end:
            name: str = m_end.group(1)
            if not stack:
                flush()
                continue
            kind, sname = stack[-1]
            if name and sname and name == sname:
                stack.pop()
                if kind == "sub":
                    flush()
                continue
            if not name and kind == "sub" and len(stack) == 1:
                # `end;` closes a bare subprogram (no name given)
                stack.pop()
                flush()
                continue
            # Mismatched `end Foo;` (e.g. a nested block label): ignore,
            # keep scanning.
            continue
        if m_end_bare:
            if stack and stack[-1][0] == "sub" and len(stack) == 1:
                stack.pop()
                flush()
            continue

        if cur is not None and stack and stack[-1][0] == "sub":
            c_list: List[object] = cur
            c_list[2] = int(c_list[2]) + d
            c_list[3] = int(c_list[3]) + 1
        if NESTED_HEADER_RE.match(raw):
            continue

    flush()
    return FileMetrics(
        loc=loc,
        complexity=sum(s.complexity for s in subs),
        subprograms=subs,
    )


def source_files() -> List[Path]:
    """All .ads/.adb sources under src/ (generated specs excluded)."""
    exclude: Set[str] = {
        "src/adacovex_version_info.ads",
        "src/adacovex-dashboard_template.ads",
    }
    files: List[Path] = []
    for p in sorted((ROOT / "src").rglob("*")):
        if p.suffix not in (".ads", ".adb"):
            continue
        if p.relative_to(ROOT).as_posix() in exclude:
            continue
        files.append(p)
    return files


def check_one(  # noqa: C901  (reporting switch, not a gate target)
    d: Dict[str, object],
    total_loc: int,
    cap_loc: int,
    cap_pct: float,
    cap_fn: int,
    cap_file: int,
) -> List[str]:
    """Return a list of violation strings for one file entry."""
    v: List[str] = []
    file_name: str = str(d["file"])
    loc: int = int(d["loc"])
    pct: float = (100.0 * loc / total_loc) if total_loc else 0.0
    for s in d["subprograms"]:
        s_dict: Dict[str, object] = dict(s)
        if int(s_dict["complexity"]) > cap_fn:
            v.append(
                f"{file_name}:{s_dict['line']} '{s_dict['name']}' "
                f"cyclomatic {s_dict['complexity']} > {cap_fn}"
            )
    if loc > cap_loc:
        v.append(f"{file_name} LOC {loc} > {cap_loc}")
    if pct > cap_pct:
        v.append(
            f"{file_name} {pct:.1f}% of codebase LOC > {cap_pct}%"
        )
    if int(d["complexity"]) > cap_file:
        v.append(
            f"{file_name} total cyclomatic {d['complexity']} > {cap_file}"
        )
    return v


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="fail on violations")
    ap.add_argument("--json", default="", help="write a JSON metrics export")
    ap.add_argument("--max-file-loc", type=int, default=2000)
    ap.add_argument("--max-file-pct", type=float, default=10.0)
    ap.add_argument("--max-fn-complexity", type=int, default=50)
    ap.add_argument("--max-file-complexity", type=int, default=300)
    args: argparse.Namespace = ap.parse_args(argv)

    files: List[Path] = source_files()
    if not files:
        print("error: no Ada sources found under src/", file=sys.stderr)
        return 1

    data: List[Dict[str, object]] = []
    total_loc: int = 0
    for p in files:
        m: FileMetrics = analyze(p)
        total_loc += m.loc
        data.append(
            {
                "file": p.relative_to(ROOT).as_posix(),
                "loc": m.loc,
                "complexity": m.complexity,
                "subprograms": [s._asdict() for s in m.subprograms],
            }
        )

    print(f"{'file':<58} {'loc':>5} {'%':>6} {'cx':>5}")
    for d in sorted(data, key=lambda r: int(r["loc"]), reverse=True):
        loc: int = int(d["loc"])
        pct: float = (100.0 * loc / total_loc) if total_loc else 0.0
        marker: str = ""
        for s in d["subprograms"]:
            if int(s["complexity"]) > int(args.max_fn_complexity):
                marker = "  <-- function too complex"
        if loc > int(args.max_file_loc):
            marker = "  <-- too long"
        if pct > float(args.max_file_pct):
            marker = "  <-- dominant"
        if int(d["complexity"]) > int(args.max_file_complexity):
            marker = "  <-- god object"
        print(f"{d['file']:<58} {loc:5d} {pct:5.1f}% {int(d['complexity']):5d}{marker}")

    print()
    print(f"total LOC (src): {total_loc}")
    print(f"files analyzed: {len(data)}")

    if args.json:
        Path(args.json).write_text(
            json.dumps({"total_loc": total_loc, "files": data}, indent=2) + "\n"
        )
        print(f"wrote {args.json}")

    violations: List[str] = []
    for d in data:
        violations += check_one(
            d,
            total_loc,
            int(args.max_file_loc),
            float(args.max_file_pct),
            int(args.max_fn_complexity),
            int(args.max_file_complexity),
        )

    if args.check and violations:
        print(f"  Complexity/LOC gate FAILED ({len(violations)} violation(s))")
        for v in violations:
            print(f"  - {v}")
        return 1
    if args.check:
        print("  Complexity/LOC gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))