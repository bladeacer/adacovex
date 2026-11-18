#!/usr/bin/env python3
"""Fail when a test assumes a POSIX host without saying so.

The native suite and the Python end-to-end suites must pass on Windows,
macOS, and Linux. A test may still need one host: then it states the host and
skips with a reason. A hard-coded POSIX path, shell invocation, or permission
bit silently fails instead.

This gate scans the test sources (not the fixture projects, whose Ada text is
the subject of the test) for the known host-specific shapes:

  /tmp, /dev/null, /proc, `sh -c`, `bash -c`, `rm -rf`, `chmod`, `uname`,
  `mktemp`, `os.system`, `shell=True`, and a POSIX `#!` shebang.

An Ada comment is prose, so only the code part of an Ada line is scanned.
The allow-list below is the documented escape hatch: a line whose rule and
file match an entry is known to be a deliberate platform assertion or a
fixture's own text. Add an entry only with the reason it is safe; a skip in
the suite is the normal answer and never needs one.

Usage:
  python3 tools/check-test-portability.py

Exit code 0 when every test source is portable or allowed, 1 when a new
host-specific shape appears.
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
TEST_ROOT: Path = ROOT / "src" / "tests"

SUFFIXES: Tuple[str, ...] = (".adb", ".ads", ".py", ".ts", ".mjs", ".js")

#  Vendored tools and test output are not test sources: they are installed
#  packages or generated reports, and their host probes are someone else's
#  code.  Prune them before scanning.
PRUNE_NAMES: Tuple[str, ...] = (
    "node_modules", "playwright-report", "test-results",
)

#  (rule name, compiled pattern, what to use instead).
RULES: Tuple[Tuple[str, re.Pattern, str], ...] = (
    ("/tmp", re.compile(r"/tmp(?:/|\b)"),
     "use the host temp directory"),
    ("/dev/null", re.compile(r"/dev/null"),
     "use os.devnull or GNAT.OS_Lib.Null_Device"),
    ("/proc", re.compile(r"/proc/"),
     "ask the host API instead of reading /proc"),
    ("sh -c", re.compile(r"\bsh\s+-[a-z]*c\b"),
     "spawn an argument vector, not a shell string"),
    ("bash -c", re.compile(r"\bbash\s+-[a-z]*c\b"),
     "spawn an argument vector, not a shell string"),
    ("rm -rf", re.compile(r"\brm\s+-rf\b"),
     "remove the tree through the host API"),
    ("chmod", re.compile(r"\bchmod\b"),
     "skip the check when the host has no executable bit"),
    ("uname", re.compile(r"\buname\b"),
     "use the host platform helper"),
    ("mktemp", re.compile(r"\bmktemp\b"),
     "create the temp directory from the test support unit"),
    ("os.system", re.compile(r"\bos\.system\s*\("),
     "spawn an argument vector"),
    ("shell=True", re.compile(r"shell\s*=\s*True"),
     "spawn an argument vector"),
    ("POSIX shebang", re.compile(r"#![ \t]*/bin/(?:sh|bash)\b"),
     "a fake client is POSIX-only, so skip the check on Windows"),
)

#  (relative path, rule name, why the shape is safe here).
ALLOW: Tuple[Tuple[str, str, str], ...] = (
    ("src/tests/adacovex_cpus_tests.adb", "/tmp",
     "the package's documented TMPDIR/TEMP/TMP fallback is the value tested"),
    ("src/tests/adacovex_vcs_tests.adb", "/dev/null",
     "the POSIX shell's null device is the mapping under test"),
    ("src/tests/adacovex_sbom_tests.adb", "POSIX shebang",
     "the shebang is build-script fixture text the scanner reads"),
    ("src/tests/adacovex_sbom_tests.adb", "uname",
     "the tool name is generated build-state fixture text"),
    ("src/tests/e2e/cli/cli_flags.py", "POSIX shebang",
     "the fake tldr client is a shell stub; the check skips on Windows"),
    ("src/tests/e2e/cli/cli_flags.py", "chmod",
     "marks the stub executable; the check skips on Windows"),
)

ALLOWED: Dict[Tuple[str, str], str] = {
    (path, rule): reason for path, rule, reason in ALLOW
}


def _code_text(path: Path, line: str) -> str:
    """Strip a line's comment so prose is never flagged.

    @param path  Source file the line comes from.
    @param line  One physical line.
    @return The code part of the line.
    """
    suffix = path.suffix
    if suffix in (".adb", ".ads"):
        index = line.find("--")
        return line if index < 0 else line[:index]
    if suffix == ".py":
        stripped = line.lstrip()
        return "" if stripped.startswith("#") else line
    stripped = line.lstrip()
    if stripped.startswith(("//", "/*", "*")):
        return ""
    return line


def _scan(path: Path, rel: str) -> List[str]:
    """Return every unallowed host-specific shape in one test source.

    @param path  File to scan.
    @param rel  Path relative to the repository root (for the report).
    @return Problem strings.
    """
    problems: List[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for number, raw in enumerate(text.splitlines(), 1):
        code = _code_text(path, raw)
        if not code:
            continue
        for rule, pattern, hint in RULES:
            if pattern.search(code) is None:
                continue
            if (rel, rule) in ALLOWED:
                continue
            problems.append(
                f"{rel}:{number}: {rule} -- {hint}")
    return problems


def main() -> int:
    """Scan every test source and return the exit code.

    @return 0 when the tests are portable or allowed, 1 otherwise.
    """
    problems: List[str] = []
    scanned = 0
    for path in sorted(TEST_ROOT.rglob("*")):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        parts = path.relative_to(TEST_ROOT).parts
        if "projects" in parts[:-1] or any(
                name in parts[:-1] for name in PRUNE_NAMES):
            #  Fixture text is the subject of the test, not test code, and a
            #  vendored package is installed copy, not authored test code.
            continue
        scanned += 1
        problems.extend(_scan(path, str(path.relative_to(ROOT))))

    if problems:
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        print(f"Test portability check FAILED "
              f"({len(problems)} problem(s))", file=sys.stderr)
        return 1
    print(f"Test portability: {scanned} test source(s) scanned, "
          f"{len(ALLOW)} documented allow-list entr(ies).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
