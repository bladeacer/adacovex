#!/usr/bin/env python3
"""Check the diagnostics support matrix against the code and fixtures.

`docs/contributing/proving-diagnostics.md` holds one row per gnatprove check
kind (between the `diagnostic-matrix` markers).  The row states whether the
kind is Supported, Hinted, or a Fallback, which fix-hint keyword covers it,
and which fixture proves it.

This gate fails when the three sources drift:

* a `Fix_Hint` keyword in `Adacovex.Prove_Output` has no matrix row;
* a fixture directory under `src/tests/projects/contract-errors/` has no
  matrix row;
* a row marked Supported names a fixture that does not exist.

Usage: python3 tools/check-diagnostic-coverage.py
Exit code 0 when the matrix agrees with the code and the fixtures, 1 when it
does not.
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
MATRIX: Path = ROOT / "docs" / "contributing" / "proving-diagnostics.md"
PROVE_OUTPUT: Path = ROOT / "src" / "core" / "adacovex-prove_output.adb"
CONTRACT_DIR: Path = ROOT / "src" / "tests" / "projects" / "contract-errors"

BEGIN_MARKER: str = "<!-- diagnostic-matrix:begin -->"
END_MARKER: str = "<!-- diagnostic-matrix:end -->"

Row = Dict[str, str]


def matrix_rows() -> List[Row]:
    text = MATRIX.read_text(encoding="utf-8")
    if BEGIN_MARKER not in text or END_MARKER not in text:
        raise SystemExit(f"error: {MATRIX} is missing the diagnostic-matrix "
                         "markers")
    block = text[text.index(BEGIN_MARKER):text.index(END_MARKER)]
    rows: List[Row] = []
    for raw in block.splitlines():
        line = raw.strip()
        if not line.startswith("|") or line.startswith("|---"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 6 or cells[0] == "Case":
            continue
        case = cells[0].strip("`")
        rows.append({
            "case": case,
            "kind": cells[1],
            "keywords": cells[2],
            "counterexample": cells[3],
            "status": cells[4],
            "fixture": cells[5].strip("`"),
        })
    return rows


def fix_hint_keywords() -> Set[str]:
    text = PROVE_OUTPUT.read_text(encoding="utf-8")
    start = text.index("function Fix_Hint")
    end = text.index("end Fix_Hint;", start)
    return set(re.findall(r'Index \(Kind, "([^"]+)"\)', text[start:end]))


def fixture_names() -> Set[str]:
    names: Set[str] = set()
    if CONTRACT_DIR.is_dir():
        for child in CONTRACT_DIR.iterdir():
            if child.is_dir():
                names.add(child.name)
    return names


def main() -> int:
    rows = matrix_rows()
    cases = {row["case"] for row in rows}
    fixtures = fixture_names()
    keywords = fix_hint_keywords()
    documented: Set[str] = set()
    for row in rows:
        for keyword in row["keywords"].replace(",", " ").split():
            documented.add(keyword.strip("`"))

    problems: List[str] = []

    for keyword in sorted(keywords - documented):
        problems.append(f"Fix_Hint keyword {keyword!r} has no matrix row")
    for keyword in sorted(documented - keywords):
        if keyword != "fallback" and keyword != "none":
            problems.append(f"matrix keyword {keyword!r} has no Fix_Hint branch")

    for name in sorted(fixtures - cases):
        problems.append(f"fixture {name!r} has no matrix row")
    for row in rows:
        if not row["status"].startswith("Supported"):
            continue
        fixture = row["fixture"]
        if fixture != "-" and fixture not in fixtures:
            problems.append(
                f"Supported row {row['case']!r} names missing fixture "
                f"{fixture!r}")
    for row in rows:
        if row["fixture"] != "-" and row["fixture"] not in fixtures:
            problems.append(
                f"row {row['case']!r} names a fixture that does not exist")

    if problems:
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        print(f"Diagnostic coverage check FAILED "
              f"({len(problems)} problem(s))", file=sys.stderr)
        return 1
    print(f"Diagnostic coverage: {len(rows)} matrix row(s), "
          f"{len(fixtures)} fixture(s), {len(keywords)} hint keyword(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
