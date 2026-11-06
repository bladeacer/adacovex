#!/usr/bin/env python3
"""End-to-end checks for the `prove` output modes and the diagnostics block.

1.65.0 made a local `prove` run quiet: it captures the gnatprove stream and
replays one framed block without the `Phase N of M:` banners or the
suppressed notice blocks.  1.66.0 added a diagnostics block after that
replay: the prover identity, the source location and check kind of every
unproved finding, and a fix hint.

This script generates one small SPARK project per case, each with a **broken**
variant and a **fixed** counterpart that differ in one contract line.  The
broken variant is the mistake a contract writer makes, and the fixed variant
proves, so the before and after are one command apart.

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

  python3 tests/e2e/prove_diagnostics.py           # check, then clean up
  python3 tests/e2e/prove_diagnostics.py --keep    # also write the projects
                                                   # to obj/prove-diagnostics/
  python3 tests/e2e/prove_diagnostics.py --case=index --debug
                                                   # one case, full output

The fixture pins gnatprove in its own `alire.toml` (the same version
`alire-dev.toml` pins), so a host that ran `just prove` already holds the
deployment and no check downloads a toolchain.  The check skips itself when
no gnatprove is resolvable.

Exit code 0 when every check passes, 1 otherwise.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, NamedTuple, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parents[2]

#  The gnatprove version the fixture pins.  It matches alire-dev.toml, so the
#  deployment the prove gate already made is reused.
GNATPROVE_PIN: str = "16.1.0"

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


class Case(NamedTuple):
    """One contract-writing mistake with its fixed counterpart."""

    name: str
    spec: str
    body: str
    fixed_spec: str
    fixed_body: str
    kind: str
    """The check kind the block must name, or "" for a compile-error case."""


def _package(spec: str, body: str, fixed_spec: Optional[str] = None,
             fixed_body: Optional[str] = None,
             kind: str = "") -> Tuple[str, str, str, str, str]:
    """Wrap a broken spec/body pair and its fixed counterpart for a case.

    @param spec  Spec declarations of the broken variant.
    @param body  Body declarations of the broken variant.
    @param fixed_spec  Fixed spec declarations (None reuses the broken spec).
    @param fixed_body  Fixed body declarations (None reuses the broken body).
    @param kind  Check kind the block must name ("" for a compile error).
    @return The five case texts, without the name.
    """
    return (
        spec,
        body,
        fixed_spec if fixed_spec is not None else spec,
        fixed_body if fixed_body is not None else body,
        kind,
    )


_SPEC: str = """\
--  Prove diagnostics end-to-end fixture.
package {unit}
  with SPARK_Mode => On
is
{decls}end {unit};
"""

_BODY: str = """\
package body {unit}
  with SPARK_Mode => On
is

{decls}end {unit};
"""


def _case(name: str, spec: str, body: str,
          fixed_spec: Optional[str] = None,
          fixed_body: Optional[str] = None, kind: str = "") -> Case:
    """Build one case from its Ada texts.

    @param name  Case name, used for the crate and the output directory.
    @param spec  Broken spec declarations.
    @param body  Broken body declarations.
    @param fixed_spec  Fixed spec declarations (None reuses the broken spec).
    @param fixed_body  Fixed body declarations (None reuses the broken body).
    @param kind  Check kind the block must name ("" for a compile error).
    @return The assembled case.
    """
    return Case(name, *_package(spec, body, fixed_spec, fixed_body, kind))


CASES: Tuple[Case, ...] = (
    _case(
        "index",
        """\
   type Table is array (Positive range <>) of Integer;

   --  Read one element of a table.
   --  @param T  Table to read.
   --  @param I  Index to read.
   --  @return The element at I.
   function Element (T : Table; I : Positive) return Integer
     with Pre => I <= T'Length;
""",
        """\
   function Element (T : Table; I : Positive) return Integer is
   begin
      return T (I);
   end Element;
""",
        """\
   type Table is array (Positive range <>) of Integer;

   --  Read one element of a table.
   --  @param T  Table to read.
   --  @param I  Index to read.
   --  @return The element at I.
   function Element (T : Table; I : Positive) return Integer
     with Pre => I in T'Range;
""",
        kind="index check",
    ),
    _case(
        "overflow",
        """\
   --  Quadruple a bounded value.
   --  @param X  Value to quadruple.
   --  @return Four times X.
   function Quad (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000_000_000,
          Post => Quad'Result = 4 * X;
""",
        """\
   function Quad (X : Integer) return Integer is
   begin
      return 4 * X;
   end Quad;
""",
        """\
   --  Quadruple a bounded value.
   --  @param X  Value to quadruple.
   --  @return Four times X.
   function Quad (X : Integer) return Integer
     with Pre  => X in 0 .. 500_000_000,
          Post => Quad'Result = 4 * X;
""",
        kind="overflow check",
    ),
    _case(
        "division",
        """\
   --  Divide X by Y.
   --  @param X  Dividend.
   --  @param Y  Divisor.
   --  @return X divided by Y.
   function Ratio (X : Integer; Y : Integer) return Integer
     with Pre  => X in -100 .. 100,
          Post => Ratio'Result = X / Y;
""",
        """\
   function Ratio (X : Integer; Y : Integer) return Integer is
   begin
      return X / Y;
   end Ratio;
""",
        """\
   --  Divide X by Y.
   --  @param X  Dividend.
   --  @param Y  Divisor.
   --  @return X divided by Y.
   function Ratio (X : Integer; Y : Integer) return Integer
     with Pre  => X in -100 .. 100 and Y /= 0,
          Post => Ratio'Result = X / Y;
""",
        kind="divide by zero",
    ),
    _case(
        "precondition",
        """\
   --  Return a non-negative value.
   --  @param X  Value to pass.
   --  @return X.
   function Non_Neg (X : Integer) return Integer
     with Pre => X >= 0;

   --  Call the checked subprogram without a guard.
   --  @param X  Value to pass.
   --  @return The result.
   function Unchecked_Call (X : Integer) return Integer
     with Pre => X in -10 .. 10;
""",
        """\
   function Non_Neg (X : Integer) return Integer is
   begin
      return X;
   end Non_Neg;

   function Unchecked_Call (X : Integer) return Integer is
   begin
      return Non_Neg (X);
   end Unchecked_Call;
""",
        """\
   --  Return a non-negative value.
   --  @param X  Value to pass.
   --  @return X.
   function Non_Neg (X : Integer) return Integer
     with Pre => X >= 0;

   --  Call the checked subprogram behind a guard.
   --  @param X  Value to pass.
   --  @return The result.
   function Unchecked_Call (X : Integer) return Integer
     with Pre => X in 0 .. 10;
""",
        kind="precondition",
    ),
    _case(
        "invariant",
        """\
   --  Sum the values from 1 to N.
   --  @param N  Upper bound.
   --  @return The sum.
   function Sum_To (N : Natural) return Natural
     with Pre  => N <= 1_000,
          Post => Sum_To'Result = N * (N + 1) / 2;
""",
        """\
   function Sum_To (N : Natural) return Natural is
      Total : Natural := 0;
   begin
      for I in 1 .. N loop
         Total := Total + I;
      end loop;
      return Total;
   end Sum_To;
""",
        """\
   --  Sum the values from 1 to N.
   --  @param N  Upper bound.
   --  @return The sum.
   function Sum_To (N : Natural) return Natural
     with Pre  => N <= 1_000,
          Post => Sum_To'Result = N * (N + 1) / 2;
""",
        """\
   function Sum_To (N : Natural) return Natural is
      Total : Natural := 0;
   begin
      for I in 1 .. N loop
         pragma Loop_Invariant (Total = (I - 1) * I / 2);
         Total := Total + I;
      end loop;
      return Total;
   end Sum_To;
""",
        kind="postcondition",
    ),
    _case(
        "invariant_entry",
        """\
   --  Count down to zero.
   --  @param N  Start value.
   --  @return The final value.
   function Count_Down (N : Natural) return Natural
     with Pre  => N <= 100,
          Post => Count_Down'Result = 0;
""",
        """\
   function Count_Down (N : Natural) return Natural is
      Left : Natural := N;
   begin
      while Left > 0 loop
         pragma Loop_Invariant (Left < N);
         pragma Loop_Variant (Decreases => Left);
         Left := Left - 1;
      end loop;
      return Left;
   end Count_Down;
""",
        """\
   --  Count down to zero.
   --  @param N  Start value.
   --  @return The final value.
   function Count_Down (N : Natural) return Natural
     with Pre  => N <= 100,
          Post => Count_Down'Result = 0;
""",
        """\
   function Count_Down (N : Natural) return Natural is
      Left : Natural := N;
   begin
      while Left > 0 loop
         pragma Loop_Invariant (Left <= N);
         pragma Loop_Variant (Decreases => Left);
         Left := Left - 1;
      end loop;
      return Left;
   end Count_Down;
""",
        kind="loop invariant",
    ),
    _case(
        "flow",
        """\
   --  Add an offset to a value.
   --  @param X  Value to offset.
   --  @return X plus the offset.
   function Offset_Of (X : Integer) return Integer
     with Pre => X in 0 .. 1_000;
""",
        """\
   function Offset_Of (X : Integer) return Integer is
      Offset : Integer;
   begin
      return X + Offset;
   end Offset_Of;
""",
        """\
   --  Add an offset to a value.
   --  @param X  Value to offset.
   --  @return X plus the offset.
   function Offset_Of (X : Integer) return Integer
     with Pre => X in 0 .. 1_000;
""",
        """\
   function Offset_Of (X : Integer) return Integer is
      Offset : Integer := 0;
   begin
      return X + Offset;
   end Offset_Of;
""",
        kind="initialization",
    ),
    _case(
        "typo_attribute",
        """\
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000,
          Post => Doubled'Resul = 2 * X;
""",
        """\
   function Doubled (X : Integer) return Integer is
   begin
      return X * 2;
   end Doubled;
""",
        """\
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000,
          Post => Doubled'Result = 2 * X;
""",
    ),
    _case(
        "typo_identifier",
        """\
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. Max_Value,
          Post => Doubled'Result = 2 * X;
""",
        """\
   function Doubled (X : Integer) return Integer is
   begin
      return X * 2;
   end Doubled;
""",
        """\
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000,
          Post => Doubled'Result = 2 * X;
""",
    ),
)


def _binary() -> Path:
    """The built binary: bin/adacovex, or bin/adacovex.exe on Windows."""
    for name in ("adacovex.exe", "adacovex"):
        candidate = ROOT / "bin" / name
        if candidate.is_file():
            return candidate
    return ROOT / "bin" / "adacovex"


BIN: str = str(_binary())


class Results:
    """Count the checks and print one line per check."""

    def __init__(self) -> None:
        self.passed: int = 0
        self.failed: int = 0

    def check(self, condition: bool, label: str) -> None:
        """Record one check and print its outcome."""
        if condition:
            self.passed += 1
            print(f"  PASS: {label}")
        else:
            self.failed += 1
            print(f"  FAIL: {label}")

    def report(self) -> int:
        """Print the totals and return the process exit code."""
        print("")
        print(f"  Passed: {self.passed}  Failed: {self.failed}  "
              f"({self.passed + self.failed} checks)")
        print("")
        if self.failed:
            print("=== SOME PROVE DIAGNOSTICS CHECKS FAILED ===")
            return 1
        print("=== ALL PROVE DIAGNOSTICS CHECKS PASSED ===")
        return 0


def unit_name(crate: str) -> str:
    """The Ada package name of a crate (every part capitalised).

    @param crate  Alire crate name, such as `prove_diag_index`.
    @return The Ada unit name, such as `Prove_Diag_Index`.
    """
    return "_".join(
        part.capitalize() for part in crate.replace("-", "_").split("_"))


def write_project(root: Path, case: Case, fixed: bool) -> Path:
    """Write one complete SPARK project and return its directory.

    @param root  Parent directory of the fixture projects.
    @param case  Case whose texts the project uses.
    @param fixed  True for the fixed counterpart, False for the broken one.
    @return The project directory.
    """
    crate: str = f"prove_diag_{case.name}_{'fixed' if fixed else 'broken'}"
    project: Path = root / crate
    (project / "src").mkdir(parents=True, exist_ok=True)
    (project / "alire.toml").write_text(
        ALIRE.format(crate=crate, pin=GNATPROVE_PIN),
        encoding="utf-8", newline="\n")
    unit: str = unit_name(crate)
    spec_decls: str = case.fixed_spec if fixed else case.spec
    body_decls: str = case.fixed_body if fixed else case.body
    (project / f"{crate}.gpr").write_text(
        GPR.format(project=unit), encoding="utf-8", newline="\n")
    (project / "src" / f"{crate}.ads").write_text(
        _SPEC.format(unit=unit, decls=spec_decls),
        encoding="utf-8", newline="\n")
    (project / "src" / f"{crate}.adb").write_text(
        _BODY.format(unit=unit, decls=body_decls),
        encoding="utf-8", newline="\n")
    return project


def run_prove(project: Path, verbose: bool = False,
              extra: Optional[List[str]] = None) -> subprocess.CompletedProcess:
    """Run `prove` over one fixture project and capture everything.

    @param project  Project directory to prove.
    @param verbose  True for the raw prover stream, False for the concise mode.
    @param extra  Additional CLI arguments appended after the base ones.
    @return The completed process, with stdout and stderr combined.
    """
    argv: List[str] = [
        BIN, "prove", f"--target={project}", "--no-svg", "--no-sbom",
    ]
    if verbose:
        argv.append("--verbose")
    argv.extend(extra or [])
    return subprocess.run(
        argv, cwd=str(project), capture_output=True, text=True,
        timeout=900, errors="replace")


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
    broken: Path = write_project(root, case, fixed=False)
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
    broken: Path = write_project(root, case, fixed=False)
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

    fixed: Path = write_project(root, case, fixed=True)
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
        check_modes(r, root, args.debug)
        for case in selected:
            print("")
            check_case(r, root, case, args.debug)
    finally:
        if cleanup is not None:
            cleanup.cleanup()
    if args.keep:
        print(f"fixture projects kept at {keep_dir}")
    return r.report()


if __name__ == "__main__":
    sys.exit(main())
