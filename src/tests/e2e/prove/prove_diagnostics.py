#!/usr/bin/env python3
"""End-to-end checks for the `prove` output modes and the diagnostics block.

1.65.0 made a local `prove` run quiet: it captures the gnatprove stream and
replays one framed block without the `Phase N of M:` banners or the
suppressed notice blocks.  1.66.0 added a diagnostics block after that
replay: the prover identity, the source location and check kind of every
unproved finding, and a fix hint.

Every case is a real project tree under
`src/tests/projects/contract-errors/<class>/`: a **broken** variant and a
**fixed** counterpart that differ in one contract line.  The broken variant is
the mistake a contract writer makes, and the fixed variant proves, so the
before and after are one command apart.  `case.toml` states the check the
diagnostics block must name.

The cases cover the mistakes that dominate contract writing:

* `index` -- an index bound that does not imply the table bounds;
* `overflow` -- a bound too wide for the arithmetic in the body;
* `division` -- a divisor the precondition does not exclude as zero;
* `precondition` -- a caller that cannot establish the callee's contract;
* `invariant` -- a loop without the invariant its postcondition needs;
* `invariant_entry` -- a loop invariant the body keeps but the first
  iteration does not hold yet;
* `flow` -- an object read before it is written;
* `typo_attribute` -- a misspelled attribute in a postcondition;
* `typo_identifier` -- a misspelled name in a precondition.

The last two are compile errors, so the check pins the opposite behaviour: the
replay keeps the error with its location, the run fails loudly, and no
diagnostics block appears.  A finding is not an error.

  python3 src/tests/e2e/prove/prove_diagnostics.py
  python3 src/tests/e2e/prove/prove_diagnostics.py --keep
      # stage the project copies in obj/prove-diagnostics/
  python3 src/tests/e2e/prove/prove_diagnostics.py --case=index --debug
      # one case, full output

The fixture pins gnatprove in its own `alire.toml` (the same version
`alire-dev.toml` pins), so a host that ran `just prove` already holds the
deployment and no check downloads a toolkit.  The check skips itself when
no gnatprove is resolvable.

Exit code 0 when every check passes, 1 otherwise.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.e2e_support import (  # noqa: E402  (path set above)
    BIN, ROOT, Results, base_env,
)

GPR: str = """\
project {project} is
   for Source_Dirs use ("src");
   for Object_Dir use "obj";
end {project};
"""

ALIRE: str = """\
name = "{crate}"
version = "0.1.0"
project-files = ["{crate}.gpr"]

[[depends-on]]
gnatprove = "^{pin}"
"""


CASES_DIR: Path = ROOT / "src" / "tests" / "projects" / "contract-errors"

#  The documented order keeps the index case first (the output-mode checks
#  prove it) and the typo cases last.
CASE_ORDER: Tuple[str, ...] = (
    "index", "overflow", "division", "precondition", "invariant",
    "invariant_entry", "flow", "typo_attribute", "typo_identifier",
)


class Case(NamedTuple):
    """One contract-writing mistake with its fixture project pair."""

    name: str
    #  The check kind the block must name, or "" for a compile-error case.
    kind: str
    compile_error: bool
    broken: Path
    fixed: Path


def _case_metadata(path: Path) -> Tuple[str, bool]:
    """Read the expected kind and shape from a case's `case.toml`.

    @param path  The case metadata file.
    @return The check kind (empty for a compile error) and the compile flag.
    """
    kind: str = ""
    compile_error: bool = False
    for raw in path.read_text(encoding="utf-8").splitlines():
        line: str = raw.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key == "kind":
            kind = value.strip().strip('"')
        elif key == "compile_error":
            compile_error = value.lower() == "true"
    return kind, compile_error


def load_cases() -> Tuple[Case, ...]:
    """Load every committed contract-error fixture pair.

    @return The cases in documented order, then any newer case by name.
    """
    if not CASES_DIR.is_dir():
        raise SystemExit(f"error: fixture root missing: {CASES_DIR}")
    found: Dict[str, Path] = {
        child.name: child for child in CASES_DIR.iterdir() if child.is_dir()
    }
    ordered: List[str] = [name for name in CASE_ORDER if name in found]
    ordered += sorted(name for name in found if name not in CASE_ORDER)
    cases: List[Case] = []
    for name in ordered:
        base: Path = found[name]
        meta: Path = base / "case.toml"
        broken: Path = base / "broken"
        fixed: Path = base / "fixed"
        if not meta.is_file() or not broken.is_dir() or not fixed.is_dir():
            raise SystemExit(
                f"error: {base} needs case.toml, broken/, and fixed/")
        kind, compile_error = _case_metadata(meta)
        cases.append(Case(name, kind, compile_error, broken, fixed))
    return tuple(cases)


CASES: Tuple[Case, ...] = load_cases()


def stage_project(root: Path, case: Case, fixed: bool) -> Path:
    """Copy one fixture variant into the run's scratch root.

    @param root  Parent directory of the staged projects.
    @param case  Case whose fixture pair to copy.
    @param fixed  True for the fixed counterpart, False for the broken one.
    @return The staged project directory.
    """
    source: Path = case.fixed if fixed else case.broken
    crate: str = f"prove_diag_{case.name}_{'fixed' if fixed else 'broken'}"
    project: Path = root / crate
    if project.exists():
        shutil.rmtree(project)
    shutil.copytree(source, project)
    return project


def run_prove(project: Path, verbose: bool = False,
              extra: Optional[List[str]] = None,
              env_extra: Optional[dict] = None,
              cwd: Optional[Path] = None) -> subprocess.CompletedProcess:
    """Run `prove` over one fixture project and capture everything.

    @param project  Project directory to prove.
    @param verbose  True for the raw prover stream, False for the concise mode.
    @param extra  Additional CLI arguments appended after the base ones.
    @param env_extra  Extra environment variables (for example a simulated
    GitHub Actions run).
    @param cwd  Working directory to run from (the project when omitted).
    @return The completed process, with stdout and stderr combined.
    """
    argv: List[str] = [
        BIN, "prove", f"--target={project}", "--no-svg", "--no-sbom",
        "-j", "1",
    ]
    if verbose:
        argv.append("--verbose")
    argv.extend(extra or [])
    #  The checks assert on plain text, so opt out of ANSI colour. The
    #  binary honours NO_COLOR exactly as it does for a redirected log.
    return subprocess.run(
        argv, cwd=str(cwd if cwd is not None else project),
        capture_output=True, text=True,
        timeout=900, errors="replace",
        env=base_env(env_extra, no_color=True))


def diagnostics_block(text: str) -> str:
    """Return the rendered diagnostics block, or "" when there is none.

    @param text  Combined output of a `prove` run.
    @return The `proof:` line, every finding line, and the `fix:` line.
    """
    lines: List[str] = text.splitlines()
    start: Optional[int] = None
    for index, line in enumerate(lines):
        if line.startswith("  proof:") and "unproved check(s)" in line:
            start = index
            break
    if start is None:
        return ""
    block: List[str] = [lines[start]]
    for line in lines[start + 1:]:
        if line.startswith("  fix:"):
            block.append(line)
            break
        if line.startswith("    "):
            block.append(line)
    return "\n".join(block)


def repeated_findings(block: str) -> List[str]:
    """Return the finding lines a diagnostics block prints more than once.

    @param block  The rendered diagnostics block, or "".
    @return Every repeated finding line, in the order it repeats.
    """
    seen: List[str] = []
    repeats: List[str] = []
    for line in block.splitlines():
        if not line.startswith("    ") or line.startswith("    ..."):
            continue
        #  Only a finding header repeats a finding. The solver, source, and
        #  fix lines below it may legitimately repeat for two findings.
        if ": error: " not in line:
            continue
        if line in seen:
            repeats.append(line)
        else:
            seen.append(line)
    return repeats


def repeated_diagnostics(text: str) -> List[str]:
    """Return diagnostic lines (a location plus a severity) printed twice.

    @param text  Combined output of a `prove` run.
    @return Every repeated diagnostic line, in the order it repeats.
    """
    seen: List[str] = []
    repeats: List[str] = []
    for line in text.splitlines():
        stripped: str = line.strip()
        if ": warning:" not in stripped and ": error:" not in stripped:
            continue
        if stripped in seen:
            repeats.append(stripped)
        else:
            seen.append(stripped)
    return repeats


def _dump(case: Case, variant: str, text: str) -> None:
    """Print one run's full output (--debug)."""
    print("")
    print(f"--- {case.name} ({variant}) ---")
    print(text.strip())
    print("--- end ---")


def check_modes(r: Results, root: Path, debug: bool) -> None:
    """Pin the 1.65.0 replay and the 1.66.0 concise/verbose split.

    @param r  Check recorder.
    @param root  Fixture root directory.
    @param debug  True to dump each full run output.
    """
    case: Case = CASES[0]
    broken: Path = stage_project(root, case, fixed=False)
    proc = run_prove(broken)
    text: str = proc.stdout + proc.stderr
    block: str = diagnostics_block(text)
    if debug:
        _dump(case, "concise", text)
    r.check("Phase 1 of 3" not in text and "Phase 3 of 3" not in text,
            "concise: the replay drops the phase-progress banners")
    r.check("filtered:" not in text,
            "concise: the filtered footer stays silent when nothing was hidden")
    r.check("ERROR: gnatprove exited" not in text,
            "concise: an unproved check is a finding, not a prover failure")
    r.check(block != "",
            "concise: the broken project renders a diagnostics block")
    r.check("unproved check(s)" in block,
            "concise: the block states how many checks are unproved")
    r.check("(prover " in block,
            "concise: the block names the prover identity")
    r.check(repeated_diagnostics(text) == [],
            "concise: a diagnostic the prover repeats is printed once")
    r.check(": error: array index check" in block,
            "concise: a finding reads as file:line:col: error: kind")
    r.check("solver: CVC5" in block,
            "concise: the block names the solver set behind the check")
    r.check("counterexample: when " in block,
            "concise: the block states the counterexample")

    #  The same facts are machine-readable as one JSON object.
    proc = run_prove(broken, extra=["--diagnostics=json"])
    json_text: str = proc.stdout + proc.stderr
    if debug:
        _dump(case, "json", json_text)
    r.check('"prover":"' in json_text,
            "json: the object names the prover")
    r.check('"kind":"array index check"' in json_text,
            "json: the object carries the check kind")
    r.check('"line": 7' in json_text,
            "json: the object carries the parsed line")
    r.check('"counterexample":"when ' in json_text,
            "json: the object carries the counterexample")

    #  Inside GitHub Actions the same finding is also an inline annotation.
    proc = run_prove(broken, env_extra={"GITHUB_ACTIONS": "true"})
    annotation_text: str = proc.stdout + proc.stderr
    if debug:
        _dump(case, "annotation", annotation_text)
    r.check("::error file=" in annotation_text
            and "line=7" in annotation_text
            and "title=SPARK proof failed::" in annotation_text,
            "ci: an unproved finding prints a GitHub Actions annotation")
    r.check(annotation_text.count("::error file=") == 1,
            "ci: one annotation per distinct finding")

    proc = run_prove(broken, verbose=True)
    text = proc.stdout + proc.stderr
    if debug:
        _dump(case, "verbose", text)
    r.check(diagnostics_block(text) == "",
            "verbose: the raw stream renders no diagnostics block")
    r.check("index check might fail" in text,
            "verbose: the raw prover finding is kept")
    r.check("filtered:" not in text,
            "verbose: the prover stream is never filtered")


def check_case(r: Results, root: Path, case: Case, debug: bool) -> None:
    """Check one case's broken and fixed variants.

    A finding case must render a block that names the check kind and a source
    file. A compile-error case must stay an error: the replay keeps it with a
    location, the run exits non-zero, and no block appears. The fixed
    counterpart of every case proves and renders no block.

    @param r  Check recorder.
    @param root  Fixture root directory.
    @param case  Case to check.
    @param debug  True to dump each full run output.
    """
    broken: Path = stage_project(root, case, fixed=False)
    proc = run_prove(broken)
    text: str = proc.stdout + proc.stderr
    block: str = diagnostics_block(text)
    if debug:
        _dump(case, "broken", text)
    if case.kind:
        r.check(block != "",
                f"{case.name}: the broken variant renders a diagnostics block")
        r.check(case.kind in block,
                f"{case.name}: the block names the {case.kind} kind")
        r.check("  fix:" in block,
                f"{case.name}: the block carries a fix hint")
        r.check(f"prove_diag_{case.name}_broken." in block,
                f"{case.name}: the block names the source file")
        r.check(": error: " in block,
                f"{case.name}: the block uses the compiler diagnostic prefix")
        r.check(repeated_findings(block) == [],
                f"{case.name}: the block names each finding once")
        r.check(repeated_diagnostics(text) == [],
                f"{case.name}: the replay prints each diagnostic once")
        if block:
            print("")
            print(f"--- {case.name} ---")
            print(block)
    else:
        r.check(block == "",
                f"{case.name}: a contract typo renders no diagnostics block")
        r.check(f"prove_diag_{case.name}_broken." in text,
                f"{case.name}: the replay keeps the error location")
        r.check("error:" in text.lower(),
                f"{case.name}: the replay keeps the compiler error")
        r.check(proc.returncode != 0,
                f"{case.name}: the run exits non-zero")
        r.check("ERROR: gnatprove exited" in text,
                f"{case.name}: the failure line states the prover exit code")

    fixed: Path = stage_project(root, case, fixed=True)
    proc = run_prove(fixed)
    text = proc.stdout + proc.stderr
    if debug:
        _dump(case, "fixed", text)
    r.check(diagnostics_block(text) == "",
            f"{case.name}: the fixed variant renders no diagnostics block")
    r.check("all checks proved" in text,
            f"{case.name}: the fixed variant proves")
    r.check(proc.returncode == 0,
            f"{case.name}: the fixed variant exits 0")
    r.check("coverage:" in text and "statements" in text
            and "subprograms" in text and "VCs" in text,
            f"{case.name}: the run prints the proof-coverage summary")

    quiet = run_prove(fixed, extra=["--no-coverage"])
    quiet_text: str = quiet.stdout + quiet.stderr
    r.check("coverage:" not in quiet_text,
            f"{case.name}: --no-coverage hides the coverage summary")
    r.check(quiet.returncode == 0 and diagnostics_block(quiet_text) == "",
            f"{case.name}: --no-coverage leaves the proof unchanged")

    if case is CASES[0]:
        #  The proof key resolves the target and the root .gpr, so the same
        #  project proved from another working directory is a warm hit.
        elsewhere = run_prove(fixed, cwd=root)
        warm_text: str = elsewhere.stdout + elsewhere.stderr
        r.check("0 miss(es)" in warm_text,
                f"{case.name}: a run from another cwd is a warm cache hit")


def main(argv: Optional[List[str]] = None) -> int:
    """Run the checks and return the exit code."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--keep", action="store_true",
        help="write the fixture projects to obj/prove-diagnostics/")
    parser.add_argument(
        "--case", default="",
        help="run only the named case (see the CASES table)")
    parser.add_argument(
        "--debug", action="store_true",
        help="print every full `prove` output")
    parser.add_argument(
        "--skip-modes", action="store_true",
        help="skip the output-mode checks (used when cases run in parallel)")
    parser.add_argument(
        "--modes-only", action="store_true",
        help="run only the output-mode checks")
    args = parser.parse_args(argv)
    if not Path(BIN).is_file():
        print(f"error: {BIN} not found; run `just build` first",
              file=sys.stderr)
        return 1

    selected: Tuple[Case, ...] = CASES
    if args.case:
        selected = tuple(c for c in CASES if c.name == args.case)
        if not selected:
            names = ", ".join(c.name for c in CASES)
            print(f"error: unknown case '{args.case}' (cases: {names})",
                  file=sys.stderr)
            return 2

    r = Results()
    print("=== adacovex prove diagnostics end-to-end checks ===")
    keep_dir: Path = ROOT / "obj" / "prove-diagnostics"
    cleanup: Optional[tempfile.TemporaryDirectory] = None
    if args.keep:
        shutil.rmtree(keep_dir, ignore_errors=True)
        keep_dir.mkdir(parents=True, exist_ok=True)
        root: Path = keep_dir
    else:
        cleanup = tempfile.TemporaryDirectory(prefix="adacovex-prove-diag-")
        root = Path(cleanup.name)

    try:
        if not args.skip_modes:
            check_modes(r, root, args.debug)
        if not args.modes_only:
            for case in selected:
                print("")
                check_case(r, root, case, args.debug)
    finally:
        if cleanup is not None:
            cleanup.cleanup()
    if args.keep:
        print(f"fixture projects kept at {keep_dir}")
    return r.report("PROVE DIAGNOSTICS")


if __name__ == "__main__":
    sys.exit(main())
