#!/usr/bin/env python3
"""Check that all tests live under one root and fixtures are real projects.

The test tree has one root (`src/tests`) and one shape:

* the Python end-to-end suites sit in a category directory under
  `src/tests/e2e/` (`cli/`, `prove/`, `dashboard/`, `action/`, `lib/`);
* every fixture under `src/tests/projects/` is a real project -- an
  `alire.toml`, a GNAT project file, a `src/` tree, and a README that names
  the check it exercises;
* a contract-error class holds `case.toml` plus a `broken/` and a `fixed/`
  project, and its metadata agrees with the fixture shape;
* no workflow writes an Ada project or manifest inline with a heredoc.

A fixture that exists only as a heredoc in a workflow is invisible to the
native suite, cannot be built alone, and drifts from the documented check.

Usage:
  python3 tools/check-test-layout.py

Exit code 0 when the layout is clean, 1 when a rule is broken.
"""

import re
import sys
from pathlib import Path
from typing import Iterable, List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
TEST_ROOT: Path = ROOT / "src" / "tests"
E2E_ROOT: Path = TEST_ROOT / "e2e"
PROJECTS_ROOT: Path = TEST_ROOT / "projects"
WORKFLOWS: Path = ROOT / ".github" / "workflows"

E2E_CATEGORIES: Tuple[str, ...] = (
    "action", "cli", "dashboard", "lib", "prove")
INLINE_TARGET = re.compile(r"cat\s*>>?\s*(?P<target>[^\s<]+)\s*<<")
INLINE_SUFFIXES: Tuple[str, ...] = (".toml", ".gpr", ".ads", ".adb")


def _readme_gaps(root: Path) -> List[str]:
    """Return the project directories under root without a README.

    @param root  Directory to walk.
    @return One problem string per missing or empty README.
    """
    problems: List[str] = []
    for alire in sorted(root.rglob("alire.toml")):
        project = alire.parent
        readme = project / "README.md"
        if not readme.is_file() or not readme.read_text(
                encoding="utf-8", errors="replace").strip():
            problems.append(f"{project.relative_to(ROOT)} has no README.md")
    return problems


def _project_gaps() -> List[str]:
    """Return every fixture project missing a required part.

    @return Problem strings, empty when every project is complete.
    """
    problems: List[str] = []
    if not PROJECTS_ROOT.is_dir():
        return [f"{PROJECTS_ROOT.relative_to(ROOT)} is missing"]
    for alire in sorted(PROJECTS_ROOT.rglob("alire.toml")):
        project = alire.parent
        rel = project.relative_to(ROOT)
        gprs = list(project.glob("*.gpr"))
        if len(gprs) != 1:
            problems.append(
                f"{rel} needs exactly one project file, found {len(gprs)}")
        if not (project / "src").is_dir():
            problems.append(f"{rel} has no src/ directory")
    problems.extend(_readme_gaps(PROJECTS_ROOT))
    return problems


def _case_gaps() -> List[str]:
    """Return every contract-error class with a missing or wrong part.

    @return Problem strings, empty when every case is complete.
    """
    problems: List[str] = []
    case_root = PROJECTS_ROOT / "contract-errors"
    if not case_root.is_dir():
        return [f"{case_root.relative_to(ROOT)} is missing"]
    for case in sorted(p for p in case_root.iterdir() if p.is_dir()):
        rel = case.relative_to(ROOT)
        meta = case / "case.toml"
        if not meta.is_file():
            problems.append(f"{rel} has no case.toml")
            continue
        fields = {"kind": "", "compile_error": "false"}
        for raw in meta.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if "=" not in line:
                continue
            key, value = (part.strip() for part in line.split("=", 1))
            if key in fields:
                fields[key] = value.strip().strip('"')
        if fields["compile_error"] == "true" and fields["kind"]:
            problems.append(
                f"{rel}/case.toml is a compile error but names a kind")
        if fields["compile_error"] != "true" and not fields["kind"]:
            problems.append(
                f"{rel}/case.toml names no check kind")
        for variant in ("broken", "fixed"):
            if not (case / variant).is_dir():
                problems.append(f"{rel} has no {variant}/ variant")
    return problems


def _e2e_gaps() -> List[str]:
    """Return every end-to-end category or suite file that is misplaced.

    @return Problem strings, empty when the categories are complete.
    """
    problems: List[str] = []
    if not E2E_ROOT.is_dir():
        return [f"{E2E_ROOT.relative_to(ROOT)} is missing"]
    for category in E2E_CATEGORIES:
        if not (E2E_ROOT / category).is_dir():
            problems.append(
                f"src/tests/e2e/{category}/ is missing")
    for child in sorted(E2E_ROOT.iterdir()):
        if child.is_file() and child.name != "README.md":
            problems.append(
                f"{child.relative_to(ROOT)} belongs in a category directory")
    required: Iterable[Path] = (
        E2E_ROOT / "cli" / "cli_flags.py",
        E2E_ROOT / "prove" / "prove_diagnostics.py",
        E2E_ROOT / "dashboard" / "playwright.config.ts",
        E2E_ROOT / "dashboard" / "package.json",
        E2E_ROOT / "lib" / "e2e_support.py",
    )
    for path in required:
        if not path.is_file():
            problems.append(f"{path.relative_to(ROOT)} is missing")
    return problems


def _workflow_gaps() -> List[str]:
    """Return every inline project heredoc in a workflow.

    @return Problem strings, empty when no workflow writes a project inline.
    """
    problems: List[str] = []
    if not WORKFLOWS.is_dir():
        return problems
    for workflow in sorted(WORKFLOWS.glob("*.yml")):
        for number, line in enumerate(
                workflow.read_text(encoding="utf-8").splitlines(), 1):
            match = INLINE_TARGET.search(line)
            if match is None:
                continue
            target = match.group("target").strip("\"'")
            if target.endswith(INLINE_SUFFIXES):
                problems.append(
                    f"{workflow.relative_to(ROOT)}:{number} writes "
                    f"{target} inline; copy a src/tests/projects tree instead")
    return problems


def main() -> int:
    """Run every layout check and return the exit code.

    @return 0 when the layout is clean, 1 otherwise.
    """
    problems: List[str] = []
    if (ROOT / "tests").exists():
        problems.append(
            "tests/ still exists; all tests live under src/tests")
    problems.extend(_e2e_gaps())
    problems.extend(_project_gaps())
    problems.extend(_case_gaps())
    problems.extend(_workflow_gaps())

    if problems:
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        print(f"Test layout check FAILED ({len(problems)} problem(s))",
              file=sys.stderr)
        return 1
    projects = len(list(PROJECTS_ROOT.rglob("alire.toml")))
    cases = len([p for p in (PROJECTS_ROOT / "contract-errors").iterdir()
                 if p.is_dir()])
    print(f"Test layout: {len(E2E_CATEGORIES)} e2e categories, "
          f"{projects} fixture project(s), {cases} contract-error case(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
