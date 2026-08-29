#!/usr/bin/env python3
"""Verify no `SPARK_Mode (Off)` appears outside the two exempted packages.

adacovex's SPARK proof discipline allows `SPARK_Mode (Off)` in exactly two
packages: `src/core/adacovex-types.ads` (the `Types.Implementation`
container package) and `src/core/adacovex-complexity.ads` (the complexity
checker).  Both instantiate non-formal `Ada.Containers`, which SPARK
forbids in `SPARK_Mode On` code; gnatprove 16.1.0 rejects such
instantiations with "not allowed in SPARK (due to entity declared with
SPARK_Mode Off)".  See docs/proof/16.1.0-ledger.md for the empirical
evidence.  `CPUs.Get_Temp_Directory` returned to `SPARK_Mode On` in
1.27.0.

The old `make spark-off-check` recipe used `grep -rn --include` +
`grep -v` pipelines; this script walks `src/` in pure Python and applies
the same rule.

Usage:
  python3 tools/spark-off-check.py   # scan src/; exit 1 on violations

Exit code 0 when no `SPARK_Mode (Off)` appears outside the two exempt
packages.
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
SRC: Path = ROOT / "src"

# Packages allowed to carry `SPARK_Mode (Off)`.
EXEMPT: Tuple[str, ...] = (
    "src/core/adacovex-types.ads",
    "src/core/adacovex-complexity.ads",
)

# Generated template constants: single big string literals that embed the
# dashboard HTML / offline manual prose (built from resources/ and docs/ by
# tools/gen-dashboard.py and tools/gen-docs.py).  They are data, not
# hand-written Ada, and the manual page legitimately quotes the phrase
# `SPARK_Mode (Off)`; the real source (resources/, docs/) is covered by the
# CSS/ASCII gates and the docs-check gate instead.
GENERATED: Tuple[str, ...] = (
    "src/adacovex-dashboard_template.ads",
    "src/adacovex-docs_template.ads",
)

# Matches either the pragma form or the aspect form.
PATTERN = re.compile(r"pragma\s+SPARK_Mode\s*\(\s*Off\s*\)|SPARK_Mode\s*=>\s*Off")


def violations() -> List[Tuple[str, int, str]]:
    found: List[Tuple[str, int, str]] = []
    for path in sorted(SRC.rglob("*")):
        if not path.is_file() or path.suffix not in (".ads", ".adb"):
            continue
        rel = path.relative_to(ROOT).as_posix()
        if any(rel == exempt or rel.startswith(exempt + "/")
               for exempt in EXEMPT):
            continue
        if any(rel == generated or rel.startswith(generated + "/")
               for generated in GENERATED):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if PATTERN.search(line):
                found.append((rel, str(lineno), line.strip()))
    return found


def main() -> int:
    print("=== SPARK_Mode Off verification ===")
    bad = violations()
    if not bad:
        print("  no SPARK_Mode (Off) outside "
              "src/core/adacovex-types.ads and src/core/adacovex-complexity.ads")
        return 0
    print("  SPARK_Mode (Off) found outside allowed packages:")
    for rel, lineno, line in bad:
        print(f"  {rel}:{lineno}: {line}")
    print("  Only Types.Implementation and Complexity may be SPARK_Mode Off")
    print("  (non-formal Ada.Containers instantiations are illegal in")
    print("  SPARK_Mode On code; see docs/proof/16.1.0-ledger.md).")
    return 1


if __name__ == "__main__":
    sys.exit(main())