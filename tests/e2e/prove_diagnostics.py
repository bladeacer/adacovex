#!/usr/bin/env python3
"""End-to-end checks for the `prove` output modes and the diagnostics block.

1.65.0 made a local `prove` run quiet: it captures the gnatprove stream and
replays one framed block without the `Phase N of M:` banners or the
suppressed notice blocks.  1.66.0 added a diagnostics block after that
replay: the prover identity, the source location and check kind of every
unproved finding, and a fix hint.

This script generates two tiny SPARK projects that differ in one expression.
`broken` returns `X + 3` where its postcondition says `2 * X`, so gnatprove
leaves a postcondition unproved.  `fixed` returns `2 * X`, so the same
contract is proved.  It runs the real binary over both and checks what a
reader sees, so the before and after are one command apart.

  python3 tests/e2e/prove_diagnostics.py           # check, then clean up
  python3 tests/e2e/prove_diagnostics.py --keep    # also write the projects
                                                   # to obj/prove-diagnostics/

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
from typing import List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parents[2]

#  The gnatprove version the fixture pins.  It matches alire-dev.toml, so the
#  deployment the prove gate already made is reused.
GNATPROVE_PIN: str = "16.1.0"

SPEC: str = """\
--  Prove diagnostics end-to-end fixture.
package {unit}
  with SPARK_Mode => On
is
   type Table is array (Positive range <>) of Integer;

   --  Read one element of a table.
   --  @param T  Table to read.
   --  @param I  Index to read.
   --  @return The element at I.
   function Element (T : Table; I : Positive) return Integer
     with Pre => I {bound};
end {unit};
"""

BODY: str = """\
package body {unit}
  with SPARK_Mode => On
is

   function Element (T : Table; I : Positive) return Integer is
   begin
      return T (I);
   end Element;

end {unit};
"""

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


def write_project(root: Path, crate: str, unit: str, bound: str) -> Path:
    """Write one complete SPARK project and return its directory.

    @param root  Parent directory of the two fixture projects.
    @param crate  Alire crate name (also the project and file base name).
    @param unit  Ada package name for the spec and body.
    @param bound  The index bound the precondition states.
    @return The project directory.
    """
    project: Path = root / crate
    (project / "src").mkdir(parents=True, exist_ok=True)
    (project / "alire.toml").write_text(
        ALIRE.format(crate=crate, pin=GNATPROVE_PIN),
        encoding="utf-8", newline="\n")
    (project / f"{crate}.gpr").write_text(
        GPR.format(project=unit), encoding="utf-8", newline="\n")
    (project / "src" / f"{crate}.ads").write_text(
        SPEC.format(unit=unit, bound=bound), encoding="utf-8", newline="\n")
    (project / "src" / f"{crate}.adb").write_text(
        BODY.format(unit=unit), encoding="utf-8", newline="\n")
    return project


def run_prove(project: Path, verbose: bool) -> subprocess.CompletedProcess:
    """Run `prove` over one fixture project and capture everything.

    @param project  Project directory to prove.
    @param verbose  True for the raw prover stream, False for the concise mode.
    @return The completed process, with stdout and stderr combined.
    """
    argv: List[str] = [
        BIN, "prove", f"--target={project}", "--no-svg", "--no-sbom",
    ]
    if verbose:
        argv.append("--verbose")
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


def check_concise_broken(r: Results, broken: Path) -> None:
    """A broken project shows the replay, then a populated diagnostics block.

    @param r  Check recorder.
    @param broken  The broken fixture project.
    """
    proc = run_prove(broken, verbose=False)
    text: str = proc.stdout + proc.stderr
    block: str = diagnostics_block(text)
    print("")
    print("--- concise `prove` over the broken project ---")
    print(text.strip())
    print("--- end ---")
    print("")

    r.check(block != "", "the broken project renders a diagnostics block")
    r.check("unproved check(s)" in block,
            "the block states how many checks are unproved")
    r.check("(prover " in block,
            "the block names the prover identity")
    r.check("prove_diag_broken.adb:" in block,
            "the block points at the source location of the finding")
    r.check("index check" in block,
            "the block names the check kind that failed")
    r.check(
        any(line.startswith("  fix:") for line in block.splitlines()),
        "the block carries a fix hint")
    r.check("--steps" in block or "subtype constraint" in block,
            "the fix hint names the next step to take")
    r.check("Phase 1 of 3" not in text and "Phase 3 of 3" not in text,
            "the concise replay drops the phase-progress banners")
    r.check("filtered:" not in text,
            "the filtered footer stays silent when no notice was hidden")
    r.check("ERROR: gnatprove exited" not in text,
            "an unproved check is a finding, not a prover failure")


def check_verbose_broken(r: Results, broken: Path) -> None:
    """`--verbose` streams the raw prover output and adds no block.

    @param r  Check recorder.
    @param broken  The broken fixture project.
    """
    proc = run_prove(broken, verbose=True)
    text: str = proc.stdout + proc.stderr
    r.check(diagnostics_block(text) == "",
            "--verbose renders no diagnostics block")
    r.check("index check might fail" in text,
            "--verbose keeps the raw prover finding")
    r.check("filtered:" not in text,
            "--verbose never filters the prover stream")


def check_concise_fixed(r: Results, fixed: Path) -> None:
    """A proved project prints no block and reports the clean result.

    @param r  Check recorder.
    @param fixed  The fixed fixture project.
    """
    proc = run_prove(fixed, verbose=False)
    text: str = proc.stdout + proc.stderr
    print("")
    print("--- concise `prove` over the fixed project ---")
    print(text.strip())
    print("--- end ---")
    print("")
    r.check(diagnostics_block(text) == "",
            "the fixed project renders no diagnostics block")
    r.check("all checks proved" in text or "Success:" in text,
            "the fixed project reports a clean proof")
    r.check(proc.returncode == 0,
            "the fixed project exits 0")


def check_deploy_identity(r: Results, broken: Path) -> None:
    """The identity the block prints is the pin the manifest declares.

    @param r  Check recorder.
    @param broken  The broken fixture project.
    """
    proc = run_prove(broken, verbose=False)
    text: str = proc.stdout + proc.stderr
    r.check(GNATPROVE_PIN in diagnostics_block(text),
            "the block names the manifest-pinned prover version")


def main(argv: Optional[List[str]] = None) -> int:
    """Run the checks and return the exit code."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--keep", action="store_true",
        help="write the fixture projects to obj/prove-diagnostics/")
    args = parser.parse_args(argv)
    if not Path(BIN).is_file():
        print(f"error: {BIN} not found; run `just build` first",
              file=sys.stderr)
        return 1

    r = Results()
    print("=== adacovex prove diagnostics end-to-end checks ===")
    keep_dir: Path = ROOT / "obj" / "prove-diagnostics"
    if args.keep:
        shutil.rmtree(keep_dir, ignore_errors=True)
        keep_dir.mkdir(parents=True, exist_ok=True)
        root: Path = keep_dir
        with_cleanup = None
    else:
        with_cleanup = tempfile.TemporaryDirectory(prefix="adacovex-prove-diag-")
        root = Path(with_cleanup.name)

    try:
        broken: Path = write_project(
            root, "prove_diag_broken", "Prove_Diag_Broken",
            "<= T'Length")
        fixed: Path = write_project(
            root, "prove_diag_fixed", "Prove_Diag_Fixed", "in T'Range")
        check_concise_broken(r, broken)
        check_verbose_broken(r, broken)
        check_concise_fixed(r, fixed)
        check_deploy_identity(r, broken)
    finally:
        if with_cleanup is not None:
            with_cleanup.cleanup()
    if args.keep:
        print(f"fixture projects kept at {keep_dir}")
    return r.report()


if __name__ == "__main__":
    sys.exit(main())
