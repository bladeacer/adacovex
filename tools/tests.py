#!/usr/bin/env python3
"""Unit tests for the tools/*.py dev scripts.

Runs under the stdlib `unittest` only (no third-party packages), matching
the tools' zero-dependency rule:

  python3 tools/tests.py
  python3 -m unittest discover -s tools -p tests.py   (same thing)

The tests exercise the pure logic of the orchestration scripts --
ascii-check, coverage-gate, dev-cmd, release, run and versions -- against
temporary directories / throwaway git repositories.  Filesystem-heavy
subprocess orchestration (build.py, bench.py) is exercised by `make check`
itself rather than duplicated here.

Exit code 0 when every test passes.
"""

import importlib
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

TOOLS: Path = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

# Hyphenated module names need importlib; the rest import directly.
ascii_check = importlib.import_module("ascii-check")
coverage_gate = importlib.import_module("coverage-gate")
dev_cmd = importlib.import_module("dev-cmd")
import release
import run
import versions

GIT_ENV: dict = {
    "GIT_AUTHOR_NAME": "adacovex test",
    "GIT_AUTHOR_EMAIL": "test@adacovex.invalid",
    "GIT_COMMITTER_NAME": "adacovex test",
    "GIT_COMMITTER_EMAIL": "test@adacovex.invalid",
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_SYSTEM": "/dev/null",
}


def git(repo: Path, *args: str) -> subprocess.CompletedProcess:
    """Run a git command inside a throwaway repository."""
    env = dict(os.environ)
    env.update(GIT_ENV)
    return subprocess.run(
        ["git"] + list(args), cwd=str(repo), env=env,
        capture_output=True, text=True,
    )


def make_git_repo(repo: Path, tags: list) -> Path:
    """Initialise a throwaway git repository AT repo, one commit + tags."""
    repo.mkdir(parents=True, exist_ok=True)
    (repo / "f.txt").write_text("hello\n", encoding="utf-8")
    git(repo, "init", "-q", "-b", "main")
    git(repo, "add", "f.txt")
    git(repo, "commit", "-q", "-m", "initial")
    for tag in tags:
        git(repo, "tag", tag)
    return repo


def write_manifest(path: Path, version: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'name = "covex"\nversion = "{version}"\n',
                    encoding="utf-8")


class TestAsciiCheck(unittest.TestCase):
    def test_repo_is_clean(self) -> None:
        self.assertEqual(ascii_check.bad_files(ascii_check.ROOT), [])

    def test_ascii_file_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "a.md").write_text("pure ascii\n", encoding="utf-8")
            self.assertEqual(ascii_check.bad_files(Path(tmp)), [])

    def test_non_ascii_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "b.md").write_bytes(b"caf\xc3\xa9\n")
            bad = ascii_check.bad_files(Path(tmp))
            self.assertEqual(len(bad), 1)
            self.assertEqual(bad[0].name, "b.md")

    def test_crlf_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "c.md").write_bytes(b"line1\r\nline2\r\n")
            self.assertEqual(len(ascii_check.bad_files(Path(tmp))), 1)

    def test_skipped_dirs_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for skipped in ("playwright-report", "test-results", "node_modules"):
                d = root / skipped
                d.mkdir()
                (d / "x.md").write_bytes(b"caf\xc3\xa9\n")
            # The repo root itself also has a bad file, so the scan must
            # only report that one -- not the skipped-dir contents.
            (root / "bad.md").write_bytes(b"caf\xc3\xa9\n")
            bad = ascii_check.bad_files(root)
            self.assertEqual([p.name for p in bad], ["bad.md"])

    def test_unsupported_extension_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "img.svg").write_bytes(b"caf\xc3\xa9\n")
            self.assertEqual(ascii_check.bad_files(Path(tmp)), [])


class TestCoverageGate(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_root = coverage_gate.ROOT
        self._tmp = tempfile.TemporaryDirectory()
        self._root = Path(self._tmp.name)

    def tearDown(self) -> None:
        coverage_gate.ROOT = self._orig_root
        self._tmp.cleanup()

    def test_tags_sorted_and_filtered(self) -> None:
        repo = make_git_repo(self._root / "repo", ["v1.0.0", "v1.5.0", "v2", "misc"])
        coverage_gate.ROOT = repo
        self.assertEqual(coverage_gate.release_tags(), ["v1.5.0", "v1.0.0"])

    def test_latest_two(self) -> None:
        self.assertEqual(coverage_gate.latest_two(["v1.5.0", "v1.0.0"]),
                         ("v1.5.0", "v1.0.0"))

    def test_requires_two_tags(self) -> None:
        repo = make_git_repo(self._root / "repo", ["v1.0.0"])
        coverage_gate.ROOT = repo
        self.assertIsNone(coverage_gate.latest_two(coverage_gate.release_tags()))


class TestRelease(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_root = release.ROOT
        self._tmp = tempfile.TemporaryDirectory()
        self._root = Path(self._tmp.name)
        # versions.py is the one subprocess helper release.py shells out to;
        # copy it into the throwaway ROOT so it runs against the temp data.
        tools_dir = self._root / "tools"
        tools_dir.mkdir()
        shutil.copy2(TOOLS / "versions.py", tools_dir / "versions.py")
        release.ROOT = self._root

    def tearDown(self) -> None:
        release.ROOT = self._orig_root
        self._tmp.cleanup()

    def test_resolve_version_from_manifest(self) -> None:
        write_manifest(self._root / "alire.toml", "9.9.9")
        self.assertEqual(release.resolve_version(""), "9.9.9")

    def test_resolve_version_argument(self) -> None:
        write_manifest(self._root / "alire.toml", "9.9.9")
        self.assertEqual(release.resolve_version("1.2.3"), "1.2.3")
        self.assertEqual(release.resolve_version("v1.2.3"), "1.2.3")

    def test_previous_tag(self) -> None:
        make_git_repo(self._root, ["v1.0.0", "v1.5.0"])
        self.assertEqual(release.previous_tag("9.9.9"), "v1.5.0")
        self.assertEqual(release.previous_tag("1.5.0"), "v1.0.0")

    def test_changelogs_between(self) -> None:
        make_git_repo(self._root, ["v1.0.0", "v1.5.0"])
        changelogs = self._root / "docs" / "changelogs"
        for version in ("1.2.0", "1.4.0", "1.6.0"):
            write_manifest(changelogs / f"adacovex-{version}.md", version)
        listed = release.changelogs_for("1.6.0", "v1.0.0")
        self.assertEqual([Path(p).name for p in listed],
                         ["adacovex-1.4.0.md", "adacovex-1.2.0.md"])

    def test_bundle(self) -> None:
        (self._root / "bin").mkdir()
        (self._root / "bin" / "adacovex").write_text("binary\n", encoding="utf-8")
        (self._root / "install.sh").write_text("#!/bin/sh\n", encoding="utf-8")
        (self._root / "LICENSE").write_text("MIT\n", encoding="utf-8")
        docs = self._root / "docs"
        docs.mkdir()
        (docs / "THIRD_PARTY_NOTICES.md").write_text("credits\n", encoding="utf-8")
        (self._root / "action.yml").write_text("name: adacovex\n", encoding="utf-8")

        release.bundle("1.2.3")

        dist = self._root / "dist"
        self.assertTrue((dist / "adacovex").is_file())
        self.assertTrue((dist / "covex").is_symlink())
        self.assertTrue((dist / "install.sh").is_file())
        self.assertTrue((dist / "THIRD_PARTY_NOTICES.md").is_file())
        with tarfile.open(self._root / "adacovex-v1.2.3.tar.gz", "r:gz") as tar:
            names = tar.getnames()
            self.assertTrue(any(n.endswith("adacovex") for n in names))
            self.assertTrue(any(n.endswith("install.sh") for n in names))
        with tarfile.open(self._root / "adacovex-action-v1.2.3.tar.gz",
                          "r:gz") as tar:
            self.assertIn("action.yml", tar.getnames())


class TestDevCmd(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_root = dev_cmd.ROOT
        self._tmp = tempfile.TemporaryDirectory()
        self._root = Path(self._tmp.name)
        dev_cmd.ROOT = self._root

    def tearDown(self) -> None:
        dev_cmd.ROOT = self._orig_root
        self._tmp.cleanup()

    def _seed(self) -> None:
        (self._root / "alire.toml").write_text("regular\n", encoding="utf-8")
        (self._root / "alire-dev.toml").write_text("dev\n", encoding="utf-8")
        alire = self._root / "alire"
        alire.mkdir()
        (alire / "settings.toml").write_text("old\n", encoding="utf-8")

    def test_swap_and_restore(self) -> None:
        self._seed()
        out = self._root / "seen.txt"
        rc = dev_cmd.swap_and_run(
            f"cat alire.toml > {out}; echo changed > alire/settings.toml; "
            "echo extra > alire/new.txt")
        self.assertEqual(rc, 0)
        # The command saw the dev manifest...
        self.assertEqual(out.read_text(encoding="utf-8"), "dev\n")
        # ...and everything was restored afterwards.
        self.assertEqual((self._root / "alire.toml").read_text(encoding="utf-8"),
                         "regular\n")
        self.assertEqual((self._root / "alire" / "settings.toml")
                         .read_text(encoding="utf-8"), "old\n")
        self.assertFalse((self._root / "alire" / "new.txt").exists())

    def test_failure_still_restores(self) -> None:
        self._seed()
        rc = dev_cmd.swap_and_run("echo boom > /dev/null; exit 3")
        self.assertEqual(rc, 3)
        self.assertEqual((self._root / "alire.toml").read_text(encoding="utf-8"),
                         "regular\n")
        self.assertTrue((self._root / "alire" / "settings.toml").is_file())

    def test_created_alire_left_when_none_existed(self) -> None:
        (self._root / "alire.toml").write_text("regular\n", encoding="utf-8")
        (self._root / "alire-dev.toml").write_text("dev\n", encoding="utf-8")
        rc = dev_cmd.swap_and_run("mkdir -p alire")
        self.assertEqual(rc, 0)
        self.assertEqual((self._root / "alire.toml").read_text(encoding="utf-8"),
                         "regular\n")
        self.assertTrue((self._root / "alire").is_dir())


class TestVersions(unittest.TestCase):
    def test_find_version(self) -> None:
        self.assertEqual(versions.find_version("docs/changelogs/adacovex-1.2.3.md"),
                         "1.2.3")
        self.assertIsNone(versions.find_version("no version here"))

    def test_version_key_ordering(self) -> None:
        self.assertLess(versions.version_key("1.9.0"), versions.version_key("1.10.0"))

    def test_sort_lines(self) -> None:
        lines = ["docs/changelogs/adacovex-1.10.0.md",
                 "docs/changelogs/adacovex-1.2.0.md",
                 "no token"]
        self.assertEqual(versions.sort_lines(lines),
                         ["docs/changelogs/adacovex-1.2.0.md",
                          "docs/changelogs/adacovex-1.10.0.md"])

    def test_set_manifest_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "m.toml"
            write_manifest(path, "1.0.0")
            self.assertTrue(versions.set_manifest_version(path, "2.0.0"))
            self.assertIn('version = "2.0.0"',
                          path.read_text(encoding="utf-8"))

    def test_set_manifest_version_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "m.toml"
            path.write_text("name = 'x'\n", encoding="utf-8")
            self.assertFalse(versions.set_manifest_version(path, "2.0.0"))

    def test_between_subprocess(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOLS / "versions.py"), "between",
             "1.0.0", "1.6.0", "--exclude", "1.6.0"],
            input="docs/changelogs/adacovex-1.4.0.md\n"
                  "docs/changelogs/adacovex-1.6.0.md\n"
                  "docs/changelogs/adacovex-0.9.0.md\n",
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(),
                         ["docs/changelogs/adacovex-1.4.0.md"])


class TestRun(unittest.TestCase):
    def test_assess_args_are_flags(self) -> None:
        flags = run.SELF_ASSESS_ARGS.split()
        self.assertTrue(len(flags) >= 5)
        for flag in flags:
            self.assertTrue(flag.startswith("--"))
            self.assertIn("=", flag)
        self.assertIn("--require-spark=Platinum", flags)
        self.assertIn("--dal=C", flags)

    def test_source_date_epoch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = make_git_repo(Path(tmp) / "repo", ["v1.0.0"])
            stamp = run.source_date_epoch(repo)
            self.assertTrue(stamp.isdigit() and int(stamp) > 0)
            plain = Path(tmp) / "plain"
            plain.mkdir()
            self.assertEqual(run.source_date_epoch(plain), "0")

    def test_assess_args_command(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOLS / "run.py"), "assess-args"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), run.SELF_ASSESS_ARGS)


if __name__ == "__main__":
    unittest.main(verbosity=2)
