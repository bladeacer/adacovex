"""Shared paths, process helpers, state flags, and gate preflights."""

import os
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path
from typing import Dict, List, Optional

ROOT: Path = Path(__file__).resolve().parent.parent.parent
PY: str = sys.executable

#  The generated specs, excluded from gnatformat.  gnatformat has no
#  exclusion flag, so `fmt` passes an explicit source list instead of -P.
#  Formatting a generated spec is destructive: gnatformat and the generator
#  disagree on layout, so a formatted spec fails the generator's byte
#  comparison, is rewritten, and is mangled again on the next fmt.
GENERATED_SPECS: List[str] = [
    "adacovex_version_info.ads",
    "adacovex-dashboard_template.ads",
    "adacovex-docs_template.ads",
    "adacovex-tldr_template.ads",
]

#  Fixture projects are Ada sources the root GPR never compiles.  Each one
#  carries its own project file and belongs to a different build (the
#  ecosystem fixtures exist to give the SBOM parser a real manifest).  Rooted
#  at these prefixes, gnatformat would format a file the project cannot see
#  and print the "not visible to the provided project" warning, so `fmt`
#  leaves them alone.  New fixture roots belong here rather than in an
#  ever-growing per-file list.
FIXTURE_ROOTS: List[str] = [
    "src/tests/fixtures/",
    "src/tests/projects/",
]

#  A parallel gate captures its child output into a thread-local buffer so
#  task_check can print the gates in their declared order after the phase
#  finishes.  A serial gate streams as before.
_PARALLEL_CAPTURE = threading.local()

#  One build, one docs bundle, and one proof run feed every gate in a single
#  `check` run.  Each flag records a product an earlier gate already made, so
#  a later gate reuses it instead of rebuilding, re-bundling, or re-proving
#  it.  `tools/build.py` regenerates the bundled offline manual among its
#  pre-build steps, so a successful build also satisfies the offline-manual
#  gate.
_BUILD_DONE = False
_BOOK_DONE = False
_PROVE_DONE = False


def run(cmd: List[str], env: Dict[str, str] = None) -> int:
    """Run a command from the repo root, streaming or capturing its output."""
    if getattr(_PARALLEL_CAPTURE, "active", False):
        proc = subprocess.run(cmd, cwd=str(ROOT), env=env,
                              capture_output=True, text=True)
        if proc.stdout:
            _PARALLEL_CAPTURE.chunks.append(proc.stdout)
        if proc.stderr:
            _PARALLEL_CAPTURE.chunks.append(proc.stderr)
        return proc.returncode
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


def py(*args: str) -> int:
    """Run a Python script with the current interpreter."""
    return run([PY, *args])


def adacovex(*args: str) -> int:
    """Run the built binary (bin/adacovex, or bin/adacovex.exe on Windows)."""
    exe = ROOT / "bin" / "adacovex"
    if os.name == "nt" and (ROOT / "bin" / "adacovex.exe").exists():
        exe = ROOT / "bin" / "adacovex.exe"
    return run([str(exe), *args])


def skip_without_alr() -> Optional[str]:
    """SKIP reason for the gates that drive the Alire toolchain."""
    return None if shutil.which("alr") else "alr is not on PATH"

def _skip_missing_dev_tool(tool: str) -> Optional[str]:
    """SKIP reason for a gate that needs a dev-manifest binary.

    gnatformat is a binary crate of `alire-dev.toml`, so it is on PATH only
    through the manifest swap `tools/dev-cmd.py` performs; probing a bare
    `alr exec` would skip the gate on every host.  The probe therefore runs
    exactly where the gate runs.  alr's own "Executable not found" is the
    only missing-tool signal: any other exit code means the binary ran (a
    tool that rejects `--version` still proves it exists).
    """
    if shutil.which("alr") is None:
        return "alr is not on PATH"
    try:
        probe = subprocess.run(
            [sys.executable, "tools/dev-cmd.py",
             f"alr exec -- {tool} --version"],
            cwd=str(ROOT), capture_output=True, text=True, timeout=600,
        )
    except subprocess.TimeoutExpired:
        return f"the {tool} probe timed out"
    except OSError:
        return f"the {tool} probe could not run"
    output = (probe.stdout or "") + (probe.stderr or "")
    if probe.returncode == 0 or "Executable not found" not in output:
        return None
    return f"{tool} is not available in the dev toolchain"

def skip_without_gnatprove() -> Optional[str]:
    """SKIP reason for the prove diagnostics e2e gate: it needs a prover."""
    return _skip_missing_dev_tool("gnatprove")

def skip_without_gnatformat() -> Optional[str]:
    """SKIP reason for `fmt`: gnatformat ships in the dev toolchain."""
    return _skip_missing_dev_tool("gnatformat")

def skip_without_gnatdoc() -> Optional[str]:
    """SKIP reason for the API docs gate.

    A deployed binary is not enough: the gnatdoc 26.0.0 Windows build
    starts and then crashes on an access violation for any project, so the
    probe also documents a one-package probe project through the same
    manifest swap the gate uses.  A tool that cannot document one package
    cannot document the tree, and that says nothing about the tree itself.
    """
    if shutil.which("alr") is None:
        return "alr is not on PATH"
    probe_dir = Path(tempfile.mkdtemp(prefix="adacovex-gnatdoc-probe-"))
    try:
        src = probe_dir / "src"
        src.mkdir()
        (src / "adacovex_gnatdoc_probe.ads").write_text(
            "package Adacovex_Gnatdoc_Probe is\n"
            "   --  Probe docstring.\n"
            "   function Answer return Integer;\n"
            "end Adacovex_Gnatdoc_Probe;\n",
            encoding="utf-8", newline="\n")
        (probe_dir / "adacovex_gnatdoc_probe.gpr").write_text(
            "project Adacovex_Gnatdoc_Probe is\n"
            '   for Source_Dirs use ("src");\n'
            '   for Object_Dir use "obj";\n'
            "end Adacovex_Gnatdoc_Probe;\n",
            encoding="utf-8", newline="\n")
        (probe_dir / "obj").mkdir()
        try:
            probe = subprocess.run(
                [sys.executable, "tools/dev-cmd.py",
                 "alr exec -- gnatdoc"
                 f" -P {probe_dir / 'adacovex_gnatdoc_probe.gpr'}"
                 " --backend=rst --generate private"
                 f" --output-dir {probe_dir / 'rst'}"],
                cwd=str(ROOT), capture_output=True, text=True, timeout=600,
            )
        except subprocess.TimeoutExpired:
            return "gnatdoc timed out on a one-package probe project"
        except OSError:
            return "the gnatdoc probe could not run"
        output = (probe.stdout or "") + (probe.stderr or "")
        if "Executable not found" in output:
            return "gnatdoc is not available in the dev toolchain"
        if probe.returncode != 0:
            return "gnatdoc cannot generate docs on this host"
        return None
    finally:
        shutil.rmtree(probe_dir, ignore_errors=True)

def skip_without_sphinx() -> Optional[str]:
    """SKIP reason for the offline manual: rebuilding it needs Sphinx."""
    try:
        import sphinx  # noqa: F401  (presence probe only)
    except ImportError:
        return "sphinx is not installed (see requirements.txt)"
    return None
