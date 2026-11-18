"""Build, proof, docs, and the tasks that produce a product once."""

import hashlib
import os
import subprocess
from pathlib import Path
from typing import List

from . import common
from .common import (GENERATED_SPECS, FIXTURE_ROOTS, PY, ROOT, adacovex,
                     py, run)


def task_build() -> int:
    """Build once per process; later gates reuse the built tree."""
    if common._BUILD_DONE or os.environ.get("ADACOVEX_ASSUME_BUILT") == "1":
        return 0
    rc = py("tools/build.py")
    common._BUILD_DONE = rc == 0
    if common._BUILD_DONE:
        common._BOOK_DONE = True
    return rc

def task_man() -> int:
    rc = task_build()
    return rc if rc != 0 else adacovex("man")

def task_test() -> int:
    rc = task_build()
    if rc != 0:
        return rc
    exe = ROOT / "bin" / "test_runner"
    if os.name == "nt" and (ROOT / "bin" / "test_runner.exe").exists():
        exe = ROOT / "bin" / "test_runner.exe"
    rc = run([str(exe)])
    #  GNAT's Text_IO terminates lines with CRLF on Windows, but the report
    #  is a tracked LF-only artifact (.gitattributes eol=lf) and the ASCII
    #  gate rejects carriage returns: normalise both copies to LF here, so
    #  `test` leaves the tree in the state the gates expect on every host.
    for rel in ("test_result.md", "docs/test_result.md"):
        p = ROOT / rel
        try:
            data = p.read_bytes()
        except OSError:
            continue
        if b"\r\n" in data:
            p.write_bytes(data.replace(b"\r\n", b"\n"))
    return rc

def task_prove() -> int:
    """Prove once per process; a second gate reads the first run's output."""
    rc = task_build()
    if rc != 0:
        return rc
    if common._PROVE_DONE:
        print("=== SPARK proof: already run in this `check` ===")
        return 0
    rc = py("tools/run.py", "prove")
    common._PROVE_DONE = rc == 0
    return rc

def fmt_sources() -> List[str]:
    """Every source file gnatformat formats.

    Generated specs and standalone fixture projects are excluded: neither
    belongs to the root project, so formatting either one is destructive or
    prints a "not visible to the provided project" warning.
    """
    paths: List[str] = []
    for p in sorted(ROOT.glob("src/**/*.ads")) + sorted(ROOT.glob("src/**/*.adb")):
        rel = p.relative_to(ROOT).as_posix()
        if p.name in GENERATED_SPECS:
            continue
        if any(rel.startswith(root) for root in FIXTURE_ROOTS):
            continue
        paths.append(rel)
    return paths

def _digest(path: Path) -> bytes:
    """Content digest of a source, used to tell a real edit from a rewrite."""
    return hashlib.sha256(path.read_bytes()).digest()

def _fmt_stamp(sources: List[Path]) -> str:
    """Digest of the formatting inputs: every source and the dev manifest.

    The manifest carries the gnatformat pin, so a tool change invalidates the
    stamp even when the sources are unchanged.
    """
    digest = hashlib.sha256()
    for path in sources:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(_digest(path))
    manifest = ROOT / "alire-dev.toml"
    if manifest.exists():
        digest.update(manifest.read_bytes())
    return digest.hexdigest()

def task_fmt() -> int:
    #  gnatformat rewrites every file it visits, even when the layout is
    #  already correct, which bumps the mtime and makes gprbuild rebuild the
    #  whole tree.  Snapshot each source's content and timestamps first, then
    #  restore the timestamps of the files whose bytes did not change.  A
    #  warm `just check` therefore gets a no-op build, while a real format
    #  edit still reaches gnatprove and the API docs in the same run.
    sources = [ROOT / rel for rel in fmt_sources()]
    before = {}
    for path in sources:
        try:
            stat = path.stat()
            before[path] = (stat.st_mtime_ns, stat.st_atime_ns,
                            _digest(path))
        except OSError:
            continue
    stamp_path = ROOT / "obj" / "adacovex-fmt.stamp"
    stamp = _fmt_stamp(sources)
    if stamp_path.is_file():
        try:
            if stamp_path.read_text(encoding="utf-8").strip() == stamp:
                print("=== fmt: sources unchanged since the last "
                      "formatted pass ===")
                rc = py("tools/gen-version.py")
                return rc if rc != 0 else py("tools/gen-dashboard.py")
        except OSError:
            pass
    sources_arg = " ".join(fmt_sources())
    #  A warm tree is already formatted: `--check` proves it without writing
    #  a byte, so the common case never touches a source mtime.  Only a
    #  genuine formatting change pays for the rewrite pass.
    check_rc = py("tools/dev-cmd.py",
                  f"alr exec -- gnatformat -U --check {sources_arg}")
    if check_rc == 0:
        stamp_path.parent.mkdir(exist_ok=True)
        stamp_path.write_text(stamp + "\n", encoding="utf-8", newline="\n")
        rc = py("tools/gen-version.py")
        return rc if rc != 0 else py("tools/gen-dashboard.py")
    cmd = "alr exec -- gnatformat -U " + sources_arg
    rc = py("tools/dev-cmd.py", cmd)
    if rc != 0:
        return rc
    for path, (mtime, atime, digest) in before.items():
        try:
            if _digest(path) == digest:
                os.utime(path, ns=(atime, mtime))
        except OSError:
            continue
    stamp_path.parent.mkdir(exist_ok=True)
    stamp_path.write_text(_fmt_stamp(sources) + "\n", encoding="utf-8",
                          newline="\n")
    rc = py("tools/gen-version.py")
    return rc if rc != 0 else py("tools/gen-dashboard.py")

def _doc_stamp() -> str:
    """Digest of every input gnatdoc reads (sources and the converter).

    The manifest carries the gnatdoc/toolchain pin, so a tool change
    invalidates the stamp even when no source changed.
    """
    digest = hashlib.sha256()
    #  The generated bundle specs are data-only string constants.  A docs or
    #  dashboard edit rewrites their bodies but never their package
    #  interface, so they must not invalidate the gnatdoc stamp.
    generated = set(GENERATED_SPECS)
    files: List[Path] = sorted(
        p for p in (ROOT / "src").rglob("*")
        if p.suffix in (".ads", ".adb") and p.is_file()
        and p.name not in generated
    )
    for extra in (ROOT / "tools" / "rst2md.py", ROOT / "adacovex.gpr",
                  ROOT / "alire-dev.toml"):
        if extra.is_file():
            files.append(extra)
    for path in files:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(_digest(path))
    return digest.hexdigest()

def task_doc() -> int:
    #  Create the staging directory from Python: the command below runs
    #  through the platform shell, and `mkdir -p` would make cmd.exe create
    #  a literal `-p` directory on Windows.
    (ROOT / "obj").mkdir(exist_ok=True)
    stamp_path = ROOT / "obj" / "adacovex-doc.stamp"
    stamp = _doc_stamp()
    if (ROOT / "docs" / "api-docs" / "index.md").is_file() \
            and stamp_path.is_file():
        try:
            if stamp_path.read_text(encoding="utf-8").strip() == stamp:
                print("=== API docs: sources unchanged since the last "
                      "gnatdoc pass ===")
                return 0
        except OSError:
            pass
    cmd = (
        "alr exec -- gnatdoc -P adacovex.gpr --backend=rst "
        "--generate private --output-dir=obj/gnatdoc-rst && "
        f'"{PY}" tools/rst2md.py obj/gnatdoc-rst docs/api-docs '
        "--prune-test-pages"
    )
    rc = py("tools/dev-cmd.py", cmd)
    if rc != 0:
        return rc
    #  The pages rst2md prunes by name only, dropped after the conversion
    #  the same way the old `rm -f` did.
    for pattern in ("test_*.md", "adacovex-test_support.md"):
        for page in (ROOT / "docs" / "api-docs").glob(pattern):
            page.unlink()
    stamp_path.write_text(stamp + "\n", encoding="utf-8", newline="\n")
    return 0

def task_book() -> int:
    """Bundle the offline manual once; the build already did it."""
    if common._BOOK_DONE:
        print("=== Offline manual: already bundled by the build ===")
        return 0
    rc = py("tools/gen-docs.py")
    common._BOOK_DONE = rc == 0
    return rc

def task_run_self() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "self")

def task_run_ada_crdt() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "ada-crdt")

def task_sbom() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "sbom")

def task_compliance() -> int:
    rc = task_build()
    if rc != 0:
        return rc
    epoch = subprocess.run(
        ["git", "show", "-s", "--format=%ct", "HEAD"],
        cwd=str(ROOT), capture_output=True, text=True,
    ).stdout.strip()
    env = dict(os.environ)
    if epoch:
        env["SOURCE_DATE_EPOCH"] = epoch
    exe = ROOT / "bin" / "adacovex"
    if os.name == "nt" and (ROOT / "bin" / "adacovex.exe").exists():
        exe = ROOT / "bin" / "adacovex.exe"
    rc = run(
        [str(exe), "-t=.", "--dal=C",
         "--emit-markdown=docs/compliance", "--no-svg", "--no-sbom"],
        env=env,
    )
    if rc != 0:
        return rc
    #  Ada.Text_IO writes CRLF on Windows; the committed files are LF.
    for name in ("docs/compliance/VERIFICATION.md",
                 "docs/compliance/TRACE.md"):
        path = ROOT / name
        if path.is_file():
            data = path.read_bytes().replace(b"\r\n", b"\n")
            path.write_bytes(data)
    return 0

def task_bench() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/bench.py")

def task_perf_bench() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/perf-bench.py")

def task_coverage_gate() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/coverage-gate.py")
