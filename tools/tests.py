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
import re
import shutil
import subprocess
import sys
import contextlib
import io
import tarfile
import tempfile
import unittest
from unittest import mock
from pathlib import Path
from typing import List, Tuple

TOOLS: Path = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

# Hyphenated module names need importlib; the rest import directly.
ascii_check = importlib.import_module("ascii-check")
coverage_gate = importlib.import_module("coverage-gate")
dev_cmd = importlib.import_module("dev-cmd")
gen_docs = importlib.import_module("gen-docs")
import release
import run
import versions
import csslint
para_split = importlib.import_module("para-split")
rst2md = importlib.import_module("rst2md")
check_book_links = importlib.import_module("check-book-links")
check_docs = importlib.import_module("check-docs")
check_docs_coverage = importlib.import_module("check-docs-coverage")

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


class TestRst2Md(unittest.TestCase):
    """rst2md sanitisation keeps generated api-docs pure ASCII."""

    def test_mojibake_em_dash_maps_to_colon(self) -> None:
        self.assertEqual(rst2md.fix_text("a\u00e2\u0080\u0094b"), "a:b")

    def test_unicode_ellipsis_maps_to_dots(self) -> None:
        # gnatdoc abbreviates long enum declarations with U+2026.
        self.assertEqual(rst2md.fix_text("a\u2026b"), "a...b")

    def test_plain_ascii_passes_through(self) -> None:
        self.assertEqual(rst2md.fix_text("type Route_Kind is"), "type Route_Kind is")


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
        flags = run.self_assess_args().split()
        self.assertTrue(len(flags) >= 5)
        for flag in flags:
            # Single -flag=value words (long or shorthand), so the string can
            # be shell-split without a value-arity table.
            self.assertTrue(flag.startswith("-"))
            self.assertIn("=", flag)
        self.assertIn("--spark=Platinum", flags)
        self.assertIn("--dal=C", flags)
        self.assertIn("-r=100", flags)
        self.assertIn("--docstrs=100", flags)
        # The test gate is derived from docs/test_result.md, never hardcoded.
        self.assertIn(f"--require-tests={run.native_test_count()}", flags)

    def test_native_test_count_reads_the_result_file(self) -> None:
        self.assertGreater(run.native_test_count(), 0)
        self.assertIn(
            "--require-tests=", run.self_assess_args())

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
        self.assertEqual(result.stdout.strip(), run.self_assess_args())


class CssSpacingTests(unittest.TestCase):
    """Pure-logic tests for tools/csslint.py (the 4px spacing gate)."""
    def test_multiple_of_4(self) -> None:
        self.assertEqual(csslint.multiple_of_4(0), 0)
        self.assertEqual(csslint.multiple_of_4(1), 4)
        self.assertEqual(csslint.multiple_of_4(4), 4)
        self.assertEqual(csslint.multiple_of_4(6), 8)
        self.assertEqual(csslint.multiple_of_4(18), 20)

    def test_conform_value(self) -> None:
        self.assertEqual(csslint.conform_value("0 0 6px"), "0 0 8px")
        self.assertEqual(csslint.conform_value("4px 12px"), "4px 12px")
        # Only px tokens change; the property name / units stay untouched.
        self.assertEqual(csslint.conform_value("padding:8px 10px"),
                         "padding:8px 12px")
        self.assertEqual(csslint.conform_value("100%"), "100%")

    def test_lint_ignores_border_px(self) -> None:
        text = "a{border:1px solid #000;margin:0 0 6px;padding:8px 10px}"
        bad = csslint.lint(text)
        self.assertTrue(any(v == "0 0 6px" for v, _ in bad))
        self.assertTrue(any(v == "8px 10px" for v, _ in bad))
        # border is not a spacing property, so 1px is never flagged.
        self.assertFalse(any(v == "1px" for v, _ in bad))

    def test_check_roundtrip(self) -> None:
        self.assertEqual(csslint.conform_value(
            csslint.conform_value("7px 12px")), "8px 12px")


class ParaSplitTests(unittest.TestCase):
    """Pure-logic tests for tools/para-split.py (the 4-sentence rule).

    The splitter must agree with the check-docs.py gate, and it must never
    cut inside an inline Markdown construct (a code span, a link, or a
    badge), which would corrupt the prose.
    """

    @staticmethod
    def _paragraph_counts(lines: List[str]) -> List[int]:
        """The sentence count of every prose paragraph in `lines`."""
        return [para_split._count_sentences(" ".join(block.lines))
                for block in para_split._walk(lines)
                if not isinstance(block, str)]

    def test_count_sentences(self) -> None:
        self.assertEqual(para_split._count_sentences("One. Two. Three. Four."),
                         4)
        # Decimals and abbreviations are not sentence breaks.
        self.assertEqual(para_split._count_sentences("v1.21.0 ships. e.g."),
                         1)
        self.assertEqual(para_split._count_sentences("No punctuation"), 0)
        # An identifier, a version, and a link query are not breaks.
        self.assertEqual(
            para_split._count_sentences("Ada.Text_IO is a package."), 1)
        self.assertEqual(
            para_split._count_sentences("See https://x.example/p?url=y now."),
            1)
        # Badge syntax holds no sentence at all.
        self.assertEqual(
            para_split._count_sentences("![tests](a.svg) ![docs](b.svg)"), 0)
        # A real ! or ? does end a sentence before a capital letter.
        self.assertEqual(para_split._count_sentences("Done! Next."), 2)
        self.assertEqual(para_split._count_sentences("Why? Because."), 2)

    def test_count_matches_the_check_docs_gate(self) -> None:
        # check-docs.py counts with its own regex; a drift between the two
        # made the splitter report files the gate accepts (and the other way).
        samples = ["One. Two. Three.", "v1.21.0 ships. e.g.", "Ada.Text_IO ok.",
                   "![b](x.svg) ![c](y.svg)", "Done! Next? Yes.",
                   "Trailing space. ", "A `code. Span` here."]
        for text in samples:
            self.assertEqual(para_split._count_sentences(text),
                             check_docs.count_sentences(text), text)

    def test_repo_check_agrees_with_docs_check(self) -> None:
        # The gate is the source of truth: the splitter flags a file exactly
        # when the gate reports a paragraph over four sentences.
        for path in para_split._doc_files():
            lines = path.read_text(encoding="utf-8").splitlines()
            with contextlib.redirect_stderr(io.StringIO()):
                gate = [e for e in check_docs.check(path)
                        if "paragraph has" in e]
            self.assertEqual(para_split._split_lines(lines) != lines,
                             bool(gate), str(path))

    def test_split_inserts_a_blank_line(self) -> None:
        out = para_split._split_block(["One. Two. Three. Four. Five. Six."])
        self.assertEqual([x for x in out if x],
                         ["One. Two. Three. Four.", "Five. Six."])
        self.assertEqual(out.count(""), 1)
        for part in out:
            self.assertLessEqual(para_split._count_sentences(part), 4)

    def test_split_keeps_whole_lines_verbatim(self) -> None:
        # A break falls between two lines; every other line stays as it was,
        # so the file keeps its wrapping instead of being unwrapped.
        block = ["One sentence that runs over", "two lines. Second. Third.",
                 "Fourth here. Fifth closes it."]
        self.assertEqual(
            para_split._split_block(block),
            ["One sentence that runs over", "two lines. Second. Third.",
             "Fourth here.", "", "Fifth closes it."])

    def test_break_never_inside_an_inline_construct(self) -> None:
        text = "`A. B.` `C. D.` `E. F.` `G. H.` I. J."
        out = para_split._split_block([text])
        # The text is unchanged apart from the inserted break, and every code
        # span stays whole (balanced backticks).
        self.assertEqual(" ".join(x for x in out if x), text)
        for line in out:
            self.assertEqual(line.count("`") % 2, 0, line)
        self.assertEqual(self._paragraph_counts(out), [3, 3])

    def test_identifier_and_badge_are_never_mangled(self) -> None:
        lines = ["![tests](docs/badges/tests.svg) ![docs](docs/badges/docs.svg)",
                 "",
                 "The type `Adacovex.Target_Profiles` holds the range. "
                 "Second. Third. Fourth. Fifth."]
        out = para_split._split_lines(lines)
        joined = "\n".join(out)
        self.assertIn("![tests](docs/badges/tests.svg)", joined)
        self.assertIn("`Adacovex.Target_Profiles`", joined)
        self.assertNotIn("! [", joined)
        self.assertNotIn("Adacovex. ", joined)
        for count in self._paragraph_counts(out):
            self.assertLessEqual(count, 4)

    def test_unsplittable_paragraph_is_left_alone(self) -> None:
        # Every sentence lies inside one code span: a break would corrupt it,
        # so the paragraph is reported instead of cut.
        text = "`One. Two. Three. Four. Five. Six.`"
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors):
            out = para_split._split_block([text])
        self.assertEqual(out, [text])
        self.assertIn("split it by hand", errors.getvalue())

    def test_compliant_paragraph_unchanged(self) -> None:
        lines = ["Just. Two. Sentences.", "On two lines.", "", "Next one."]
        self.assertEqual(para_split._split_lines(list(lines)), lines)

    def test_is_prose(self) -> None:
        self.assertFalse(para_split._is_prose("1. item"))
        self.assertFalse(para_split._is_prose("- item"))
        self.assertFalse(para_split._is_prose("| table | row |"))
        self.assertFalse(para_split._is_prose(""))
        self.assertTrue(para_split._is_prose("a normal line"))


gen_dashboard = importlib.import_module("gen-dashboard")


class TestGenDashboard(unittest.TestCase):
    def test_minify_keeps_regex_with_slashes(self) -> None:
        # A '//' (or '/*') inside a regex literal must not be treated as a
        # comment, or the dependency detail panel link detection breaks.
        src = 'if (d.website && /^https?:\\/\\//i.test(d.website)) { return 1; }'
        out = gen_dashboard.minify_js(src)
        self.assertIn("/^https?:\\/\\//i", out)
        self.assertNotIn("//i.test", out.split("/^https?:\\/\\//i", 1)[1])

    def test_minify_keeps_regex_char_class(self) -> None:
        src = "s.replace(/[&<>\"']/g, esc);"
        out = gen_dashboard.minify_js(src)
        self.assertIn("/[&<>\"']/g", out)

    def test_minify_keeps_line_comment(self) -> None:
        src = "var x = 1; // trailing comment\nvar y = 2;"
        out = gen_dashboard.minify_js(src)
        self.assertNotIn("trailing comment", out)
        self.assertIn("var x = 1;", out)
        self.assertIn("var y = 2;", out)

    def test_assemble_resources_stay_consistent(self) -> None:
        # The bundled page must still embed every module (no placeholders left
        # behind) and the scripts must be syntactically valid JS.
        root = Path(__file__).resolve().parent.parent
        page = gen_dashboard.assemble(root / "resources" / "dashboard.html")
        for placeholder in gen_dashboard.MODULES:
            self.assertNotIn(placeholder, page)
        scripts = re.findall(r"<script>(.*?)</script>", page, re.S)
        self.assertEqual(len(scripts), 11)


class TestGenDocsAssets(unittest.TestCase):
    """gen-docs.py per-asset emission (H4: gnatprove stack overflow fix)."""

    def test_operands_drop_trailing_newline(self) -> None:
        # one\ntwo -> literal "one", ASCII.LF, literal "two" (newline dropped)
        self.assertEqual(gen_docs._asset_body_lines("one\ntwo\n"),
                         ['"one"', "ASCII.LF", '"two"'])

    def test_operands_escape_quotes_and_non_ascii(self) -> None:
        lines = gen_docs._asset_body_lines('say "hi"\n\u00e9')
        self.assertIn('"say ""hi"""', lines)
        # U+00E9 is two UTF-8 bytes -> two Character'Val byte operands
        self.assertEqual(lines.count("ASCII.LF"), 1)
        self.assertEqual(len([l for l in lines
                              if l.startswith("Character'Val(")]), 2)

    def test_long_run_split_into_short_literals(self) -> None:
        body = "x" * 400
        lines = gen_docs._asset_body_lines(body)
        for l in lines:
            self.assertLessEqual(len(l), 80)  # -gnatyM120 with indentation
        joined = "".join(
            l[1:-1].replace('""', '"') if l.startswith('"') else chr(int(
                l[l.index("(") + 1:l.index(")")]))
            for l in lines)
        self.assertEqual(joined, body)

    def test_empty_line_becomes_empty_literal(self) -> None:
        self.assertEqual(gen_docs._asset_body_lines("a\n\nb"),
                         ['"a"', "ASCII.LF", '""', "ASCII.LF", '"b"'])

    def test_collect_assets_bundles_sphinx_searchindex(self) -> None:
        # Sphinx names the index searchindex.js already (no content hash), so
        # it must be bundled as-is with every page's reference intact.
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "build"
            build.mkdir()
            (build / "index.html").write_text(
                '<script src="_static/searchtools.js"></script>'
                '<script src="searchindex.js"></script>',
                encoding="utf-8")
            (build / "searchindex.js").write_text("{}", encoding="utf-8")
            assets = gen_docs.collect_assets(build)
            rels = {rel for rel, _, _ in assets}
            self.assertIn("searchindex.js", rels)

    def test_collect_assets_drops_sources_and_images(self) -> None:
        # The raw-source _sources/ copies and the PNG _images/ screenshots are
        # deliberately not bundled (their references are stripped below), the
        # _downloads/ badge SVGs are, and the footer Page source link and the
        # Furo theme self-promotion block ("Made with Sphinx and @pradyunsg's
        # Furo") are removed from every page (the copyright above them stays;
        # Sphinx and Furo are credited in THIRD_PARTY_NOTICES.md instead).
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "build"
            build.mkdir()
            (build / "index.html").write_text(
                '<a href="_sources/index.md.txt">Page source</a>'
                '<img src="_images/dashboard_preview_overview.png" '
                'alt="Preview of Overview tab">'
                '<div class="copyright">Copyright \u00a9 bladeacer</div>'
                'Made with <a href="https://www.sphinx-doc.org/">Sphinx</a> '
                'and <a class="muted-link" href="https://pradyunsg.me">'
                '@pradyunsg</a>\'s '
                '<a href="https://github.com/pradyunsg/furo">Furo</a>'
                'Powered by <a href="https://www.sphinx-doc.org/">Sphinx 9.1.0</a>',
                encoding="utf-8")
            (build / "_sources").mkdir()
            (build / "_sources" / "index.md.txt").write_text(
                "# hi", encoding="utf-8")
            (build / "_images").mkdir()
            (build / "_images" / "dashboard_preview_overview.png").write_bytes(
                b"\x89PNG\r\n")
            (build / "_downloads").mkdir()
            (build / "_downloads" / "spark.svg").write_text(
                "<svg/>", encoding="utf-8")
            assets = gen_docs.collect_assets(build)
            rels = {rel for rel, _, _ in assets}
            self.assertIn("_downloads/spark.svg", rels)
            self.assertNotIn("_sources/index.md.txt", rels)
            self.assertNotIn("_images/dashboard_preview_overview.png", rels)
            index_body = next(body for rel, _, body in assets
                              if rel == "index.html")
            self.assertNotIn("Page source", index_body)
            self.assertNotIn("<img", index_body)
            self.assertIn("see the online manual", index_body)
            self.assertNotIn("pradyunsg", index_body)
            self.assertNotIn("github.com/pradyunsg/furo", index_body)
            self.assertIn("Copyright \u00a9 bladeacer", index_body)
            self.assertIn("sphinx-doc.org", index_body)

    def test_collect_assets_bundles_badge_svgs_and_notes_pngs(self) -> None:
        # The badge previews on the badges page are SVG: they are bundled so
        # the inline preview works offline, while a raster screenshot keeps
        # the note fallback (the PNGs stay out of the bundle).
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp) / "build"
            (build / "_images").mkdir(parents=True)
            (build / "index.html").write_text(
                '<img src="_images/spark.svg" alt="badge">'
                '<img src="../_images/shot.png" alt="Preview of Overview tab">',
                encoding="utf-8")
            (build / "_images" / "spark.svg").write_text(
                "<svg/>", encoding="utf-8")
            (build / "_images" / "shot.png").write_bytes(b"\x89PNG\r\n")
            assets = gen_docs.collect_assets(build)
            rels = {rel for rel, _, _ in assets}
            self.assertIn("_images/spark.svg", rels)
            self.assertNotIn("_images/shot.png", rels)
            index_body = next(body for rel, _, body in assets
                              if rel == "index.html")
            self.assertIn("spark.svg", index_body)
            self.assertNotIn("shot.png", index_body)
            self.assertIn("see the online manual", index_body)


class TestGenDocsEncodeCache(unittest.TestCase):
    """The content-hash encode cache and the parallel encoder (1.51.0).

    gzip+base85 is the only per-asset work a no-op run still repeats.  Each
    body's chunks are cached by SHA-256 under obj/, so a docs edit re-encodes
    only the pages it touched, and the uncached bodies encode in parallel.
    Both are pure speed-ups: the emitted spec stays byte-identical.
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self._saved = gen_docs.ENCODE_CACHE
        gen_docs.ENCODE_CACHE = Path(self._tmp.name) / "cache"

    def tearDown(self) -> None:
        gen_docs.ENCODE_CACHE = self._saved
        self._tmp.cleanup()

    def test_cached_chunks_round_trip(self) -> None:
        chunks = ["abc", "def"]
        gen_docs._store_cached_chunks("deadbeef", chunks)
        self.assertEqual(gen_docs._cached_chunks("deadbeef"), chunks)
        self.assertIsNone(gen_docs._cached_chunks("missing"))

    def test_unchanged_bodies_are_not_re_encoded(self) -> None:
        assets = [("a.html", "text/html", "<a>one</a>"),
                  ("b.html", "text/html", "<b>two</b>")]
        first = gen_docs.encode_assets(assets, jobs=1)
        # A second run must read the cache, never call the encoder.
        with mock.patch.object(gen_docs, "_b85_chunks",
                               side_effect=AssertionError("re-encoded")):
            second = gen_docs.encode_assets(assets, jobs=1)
        self.assertEqual(first, second)

    def test_a_changed_body_re_encodes_and_prunes_the_old_entry(self) -> None:
        gen_docs.encode_assets([("a.html", "text/html", "<a>one</a>")],
                               jobs=1)
        old = {p.name for p in gen_docs.ENCODE_CACHE.glob("*.b85")}
        gen_docs.encode_assets([("a.html", "text/html", "<a>changed</a>")],
                               jobs=1)
        new = {p.name for p in gen_docs.ENCODE_CACHE.glob("*.b85")}
        self.assertEqual(len(new), 1)
        self.assertFalse(old & new, "the stale cache entry must be pruned")

    def test_parallel_encode_matches_the_serial_one(self) -> None:
        assets = [(f"{i}.html", "text/html", f"<p>{i}</p>" * 50)
                  for i in range(8)]
        gen_docs.ENCODE_CACHE = Path(self._tmp.name) / "serial"
        serial = gen_docs.encode_assets(assets, jobs=1)
        gen_docs.ENCODE_CACHE = Path(self._tmp.name) / "parallel"
        parallel = gen_docs.encode_assets(assets, jobs=4)
        self.assertEqual(serial, parallel)

    def test_default_jobs_is_bounded(self) -> None:
        self.assertGreaterEqual(gen_docs.default_jobs(), 1)
        self.assertLessEqual(gen_docs.default_jobs(), gen_docs.MAX_ENCODE_JOBS)


class TestGenDocsIncrementalBuild(unittest.TestCase):
    """The incremental Sphinx build and its correctness guards (1.51.0).

    Sphinx runs only when the docs sources changed, re-reads only the changed
    pages, and rewrites every page when the navigation moved.  A removed page
    is swept and the page set is checked against the sources, so the build
    directory is always a pure function of docs/ -- a fallback clean rebuild
    when the check fails, and --fresh to force one.
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.docs = root / "docs"
        (self.docs / "usage").mkdir(parents=True)
        self._saved = (gen_docs.DOCS, gen_docs.BUILD, gen_docs.STAMP)
        gen_docs.DOCS = self.docs
        gen_docs.BUILD = self.docs / "_build" / "html"
        gen_docs.STAMP = self.docs / "_build" / ".adacovex-docs-sources"
        self.write("index.md", "# Index\n\n```{toctree}\nusage/a\n```\n")
        self.write("usage/a.md", "# A\n\nOne. Two.\n")
        self.write("usage/b.md", "# B\n")

    def tearDown(self) -> None:
        gen_docs.DOCS, gen_docs.BUILD, gen_docs.STAMP = self._saved
        self._tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.docs / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def install_fake_sphinx(self) -> List[bool]:
        """Replace Sphinx: write a page per source, honouring `-a`."""
        calls: List[bool] = []

        def fake(all_pages: bool = False) -> bool:
            calls.append(all_pages)
            gen_docs.BUILD.mkdir(parents=True, exist_ok=True)
            for rel in sorted(gen_docs.docs_source_digests()):
                if not gen_docs.is_page_source(rel):
                    continue
                docname = rel[: rel.rindex(".")]
                page = gen_docs.BUILD / (docname + ".html")
                source = gen_docs.DOCS / rel
                fresh = (all_pages or not page.exists()
                         or source.stat().st_mtime_ns
                         >= page.stat().st_mtime_ns)
                if fresh:
                    page.parent.mkdir(parents=True, exist_ok=True)
                    page.write_text(f"<p>{rel}</p>", encoding="utf-8")
                    side = gen_docs.BUILD / "_sources" / f"{docname}.md.txt"
                    side.parent.mkdir(parents=True, exist_ok=True)
                    side.write_text(rel, encoding="utf-8")
                    tree = gen_docs.BUILD / ".doctrees" / f"{docname}.doctree"
                    tree.parent.mkdir(parents=True, exist_ok=True)
                    tree.write_text(rel, encoding="utf-8")
            for name in gen_docs.GENERATED_PAGES:
                (gen_docs.BUILD / name).write_text(name, encoding="utf-8")
            return True

        patcher = mock.patch.object(gen_docs, "sphinx_build", fake)
        patcher.start()
        self.addCleanup(patcher.stop)
        return calls

    def test_unchanged_tree_skips_sphinx(self) -> None:
        calls = self.install_fake_sphinx()
        self.assertTrue(gen_docs.ensure_build())
        self.assertTrue(gen_docs.ensure_build())
        self.assertEqual(calls, [False], "a no-op run must not rebuild")

    def test_edited_page_rebuilds_only_that_page(self) -> None:
        calls = self.install_fake_sphinx()
        gen_docs.ensure_build()
        untouched = gen_docs.BUILD / "usage/index.html"
        before = (gen_docs.BUILD / "index.html").read_bytes()
        self.write("usage/a.md", "# A\n\nEdited.\n")
        self.assertTrue(gen_docs.ensure_build())
        self.assertEqual(calls, [False, False], "no -a for a prose edit")
        self.assertEqual((gen_docs.BUILD / "index.html").read_bytes(), before)
        self.assertFalse(untouched.exists())

    def test_added_page_rewrites_every_page(self) -> None:
        calls = self.install_fake_sphinx()
        gen_docs.ensure_build()
        self.write("usage/c.md", "# C\n")
        self.assertTrue(gen_docs.ensure_build())
        self.assertEqual(calls, [False, True], "a new page moves the nav")
        self.assertTrue((gen_docs.BUILD / "usage/c.html").exists())

    def test_toctree_edit_rewrites_every_page(self) -> None:
        calls = self.install_fake_sphinx()
        gen_docs.ensure_build()
        self.write("index.md", "# Index\n\n```{toctree}\nusage/a\nusage/b\n```\n")
        self.assertTrue(gen_docs.ensure_build())
        self.assertEqual(calls, [False, True], "a toctree edit moves the nav")

    def test_removed_page_is_swept(self) -> None:
        self.install_fake_sphinx()
        gen_docs.ensure_build()
        (self.docs / "usage" / "b.md").unlink()
        self.assertTrue(gen_docs.ensure_build())
        self.assertFalse((gen_docs.BUILD / "usage/b.html").exists())
        self.assertFalse(
            (gen_docs.BUILD / "_sources" / "usage/b.md.txt").exists())
        self.assertFalse(
            (gen_docs.BUILD / ".doctrees" / "usage/b.doctree").exists())

    def test_stray_page_falls_back_to_a_clean_build(self) -> None:
        self.install_fake_sphinx()
        gen_docs.ensure_build()
        (gen_docs.BUILD / "stray.html").write_text("x", encoding="utf-8")
        self.assertTrue(gen_docs.ensure_build())
        self.assertFalse((gen_docs.BUILD / "stray.html").exists())
        self.assertTrue((gen_docs.BUILD / "index.html").exists())

    def test_fresh_forces_a_clean_rebuild(self) -> None:
        calls = self.install_fake_sphinx()
        gen_docs.ensure_build()
        self.assertTrue(gen_docs.ensure_build(fresh=True))
        self.assertEqual(calls, [False, False])
        self.assertTrue((gen_docs.BUILD / "usage/a.html").exists())

    def test_build_write_is_skipped_when_the_sources_are_unchanged(self) -> None:
        self.install_fake_sphinx()
        gen_docs.ensure_build()
        stamp = gen_docs.read_stamp()
        self.assertIsNotNone(stamp)
        self.assertEqual(stamp.digests,
                         gen_docs.docs_source_digests())


class TestGenDocsBuildHelpers(unittest.TestCase):
    """The pure helpers behind the incremental docs build decisions."""

    def test_changed_and_removed_sources(self) -> None:
        current = {"a.md": "1", "b/c.md": "2"}
        previous = {"a.md": "1", "b/c.md": "X", "gone.md": "3"}
        self.assertEqual(gen_docs.changed_sources(current, previous),
                         {"b/c.md"})
        self.assertEqual(gen_docs.removed_sources(current, previous),
                         {"gone.md"})
        self.assertEqual(gen_docs.changed_sources(current, None), set(current))
        self.assertEqual(gen_docs.removed_sources(current, None), set())

    def test_source_page_outputs_keeps_index_names(self) -> None:
        pages = gen_docs.source_page_outputs(
            ["index.md", "usage/index.md", "usage/a.rst", "badges/x.svg"])
        self.assertEqual(pages, {"index.html", "usage/index.html",
                                 "usage/a.html"})

    def test_stale_source_outputs_covers_pages_and_images(self) -> None:
        paths, names = gen_docs.stale_source_outputs(
            ["usage/a.md", "badges/spark.svg"])
        self.assertEqual(paths, ["usage/a.html",
                                 "_sources/usage/a.md.txt",
                                 ".doctrees/usage/a.doctree",
                                 "_images/spark.svg"])
        self.assertEqual(names, ["spark.svg"])

    def test_sweep_removes_the_files_and_download_copies(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp)
            for rel in ("_images/spark.svg", "_downloads/abc/spark.svg",
                        "_downloads/abc/keep.svg"):
                path = build / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("x", encoding="utf-8")
            saved = gen_docs.BUILD
            gen_docs.BUILD = build
            try:
                gen_docs.sweep_stale_outputs(["badges/spark.svg"])
            finally:
                gen_docs.BUILD = saved
            self.assertFalse((build / "_images/spark.svg").exists())
            self.assertFalse((build / "_downloads/abc/spark.svg").exists())
            self.assertTrue((build / "_downloads/abc/keep.svg").exists())

    def test_build_problems_reports_missing_unexpected_and_images(self) -> None:
        sources = ["index.md", "usage/a.md"]
        files = ["usage/a.html", "genindex.html", "search.html",
                 "_images/ghost.svg", "style.css"]
        problems = gen_docs.build_problems(files, sources)
        self.assertIn("missing page: index.html", problems)
        self.assertIn("unjustified image: _images/ghost.svg", problems)
        self.assertEqual(
            [p for p in problems if p.startswith("unexpected")], [])
        problems = gen_docs.build_problems(
            files + ["index.html", "stray.html"], sources)
        self.assertIn("unexpected page: stray.html", problems)
        self.assertNotIn("missing page: index.html", problems)

    def test_build_problems_accepts_a_clean_build(self) -> None:
        sources = ["index.md", "usage/a.md", "badges/spark.svg"]
        files = ["index.html", "usage/a.html", "genindex.html",
                 "search.html", "_images/spark.svg",
                 "_downloads/abc/spark.svg", "_static/basic.css",
                 "searchindex.js"]
        self.assertEqual(gen_docs.build_problems(files, sources), [])

    def test_stamp_round_trip_and_legacy_format(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            saved = gen_docs.STAMP
            gen_docs.STAMP = Path(tmp) / ".stamp"
            build = Path(tmp) / "html"
            build.mkdir()
            (build / "index.html").write_text("x", encoding="utf-8")
            saved_build = gen_docs.BUILD
            gen_docs.BUILD = build
            try:
                digests = {"index.md": "abc"}
                gen_docs.write_stamp("fp", digests)
                stamp = gen_docs.read_stamp()
                self.assertEqual(stamp.fingerprint, "fp")
                self.assertEqual(stamp.digests, digests)
                self.assertEqual(list(stamp.outputs), ["index.html"])
                # A stamp written before the sources section existed must be
                # read as "digests unknown", not as "nothing changed".
                gen_docs.STAMP.write_text("fp\n# outputs\nindex.html\n",
                                          encoding="ascii")
                self.assertIsNone(gen_docs.read_stamp().digests)
            finally:
                gen_docs.STAMP = saved
                gen_docs.BUILD = saved_build

    def test_is_page_source_and_toctree_detection(self) -> None:
        self.assertTrue(gen_docs.is_page_source("usage/a.md"))
        self.assertTrue(gen_docs.is_page_source("notes.rst"))
        self.assertFalse(gen_docs.is_page_source("badges/spark.svg"))
        with tempfile.TemporaryDirectory() as tmp:
            docs = Path(tmp)
            (docs / "index.md").write_text(
                "```{toctree}\nusage/a\n```\n", encoding="utf-8")
            (docs / "usage").mkdir()
            (docs / "usage" / "a.md").write_text("# A\n", encoding="utf-8")
            (docs / "notes.rst").write_text(
                ".. toctree::\n\n   usage/a\n", encoding="utf-8")
            # Prose that mentions the directive is not a toctree host.
            (docs / "howto.md").write_text(
                "Update the relevant `{toctree}` in `index.md`.\n",
                encoding="utf-8")
            saved = gen_docs.DOCS
            gen_docs.DOCS = docs
            try:
                marked = gen_docs.toctree_sources()
            finally:
                gen_docs.DOCS = saved
            self.assertEqual(marked, {"index.md", "notes.rst"})

    def test_tree_fingerprint_follows_the_digests(self) -> None:
        one = gen_docs.tree_fingerprint({"a.md": "1", "b.md": "2"})
        self.assertEqual(one, gen_docs.tree_fingerprint(
            {"b.md": "2", "a.md": "1"}), "order must not matter")
        self.assertNotEqual(one, gen_docs.tree_fingerprint(
            {"a.md": "1", "b.md": "3"}))


class TestGenDocsCodec(unittest.TestCase):
    """The base85 body encoding and the shared sidebar (1.50.0).

    Every asset body is gzip bytes base85-encoded onto the quote-free Z85
    alphabet, and every page carries a sidebar stub instead of the repeated
    Furo toctree.  Both are pinned here: the packing rule against the Ada
    decoder in src/adacovex-docs_template.adb, and the dedup against the
    page-independence the sharing depends on.
    """

    def test_ascii85_packing_and_length(self) -> None:
        # 4 bytes -> 5 characters; a final 1..3-byte group -> n+1 characters.
        for size in range(0, 21):
            data = bytes(range(size))
            enc = gen_docs._b85_encode(data)
            self.assertEqual(len(enc), (size * 5 + 3) // 4)
            self.assertTrue(all(c in gen_docs.B85 for c in enc))

    def test_alphabet_is_the_quote_free_z85_run(self) -> None:
        # A quote or a backslash would need escaping inside the Ada literal,
        # and a non-printable byte would break the pure-ASCII source rule.
        self.assertEqual(len(gen_docs.B85), 85)
        self.assertEqual(len(set(gen_docs.B85)), 85)
        self.assertFalse(any(c in gen_docs.B85 for c in '"\\'))
        self.assertTrue(all(32 < ord(c) < 127 for c in gen_docs.B85))

    def test_known_vectors(self) -> None:
        # Pinned against the Ada decoder: a change on either side fails here.
        self.assertEqual(gen_docs._b85_encode(b"Hello"), "nm=QNzV")
        self.assertEqual(gen_docs._b85_encode(b"\x1f\x8b\x08\x00"), "abZy8")
        self.assertEqual(gen_docs._b85_encode(b""), "")

    def test_gzip_bodies_keep_the_gzip_magic(self) -> None:
        # What the Ada side asserts on the real bundle: the decoded bytes are
        # a gzip stream, so the server's Content-Encoding: gzip is honest.
        chunks = gen_docs._b85_chunks("<html>hello</html>")
        self.assertGreaterEqual(len(chunks), 1)
        self.assertTrue(all(len(c) <= gen_docs.MAX_CHUNK_BYTES * 5 // 4 + 5
                            for c in chunks))
        self.assertEqual(chunks[0][:3], gen_docs._b85_encode(b"\x1f\x8b"))

    def test_sidebar_span_covers_nested_divs(self) -> None:
        html = ('<p>before</p>'
                + gen_docs._SIDEBAR_START
                + '<div><div>deep</div></div>after</div>'
                + '<p>after</p>')
        span = gen_docs._sidebar_span(html)
        self.assertIsNotNone(span)
        start, end = span
        self.assertEqual(html[start:end],
                         gen_docs._SIDEBAR_START
                         + '<div><div>deep</div></div>after</div>')
        self.assertIsNone(gen_docs._sidebar_span("<p>no sidebar</p>"))

    def test_sidebar_inner_excludes_the_container_element(self) -> None:
        # The stub keeps the .sidebar-container element itself, so only the
        # inner markup is shared.  Storing the wrapper would nest a second
        # container on injection and break the sticky sidebar (see
        # test_bundled_sidebar_stores_inner_markup_only).
        html = ('<p>before</p>'
                + gen_docs._SIDEBAR_START
                + '<div class="sidebar-sticky">tree</div></div>'
                + '<p>after</p>')
        span = gen_docs._sidebar_span(html)
        self.assertIsNotNone(span)
        inner = gen_docs._sidebar_inner(html, span)
        self.assertEqual(inner, '<div class="sidebar-sticky">tree</div>')
        self.assertNotIn("sidebar-container", inner)

    def test_nav_variant_is_page_independent(self) -> None:
        # Two pages of one tree highlight different entries; after the
        # normalisation their stored trees must be byte-identical, or the
        # sharing collapses into one variant per page.
        first = ('<div class="sidebar-container"><ul>'
                 '<li class="toctree-l1 current current-page">'
                 '<a class="current reference internal" href="#">A</a></li>'
                 '<li class="toctree-l1">'
                 '<a class="reference internal" href="b.html">B</a></li>'
                 '</ul></div>')
        second = ('<div class="sidebar-container"><ul>'
                  '<li class="toctree-l1">'
                  '<a class="reference internal" href="a.html">A</a></li>'
                  '<li class="toctree-l1 current current-page">'
                  '<a class="current reference internal" href="#">B</a></li>'
                  '</ul></div>')
        self.assertEqual(gen_docs._nav_variant(first, "sub/a.html"),
                         gen_docs._nav_variant(second, "sub/b.html"))

    def test_nav_variant_rebases_every_link_exactly_once(self) -> None:
        # The stored tree is fetched from _nav/, so its links are rebased onto
        # that directory.  The restored self-link must not be rebased again
        # (the doubled path this test pins was reachable before).
        block = ('<div class="sidebar-container"><ul>'
                 '<li class="toctree-l1 current current-page">'
                 '<a class="current reference internal" href="#">Here</a></li>'
                 '<li class="toctree-l1">'
                 '<a class="reference internal" href="../../root.html">Root</a>'
                 '</li></ul></div>')
        out = gen_docs._nav_variant(block, "a/b/here.html")
        self.assertIn('href="../a/b/here.html"', out)
        self.assertIn('href="../root.html"', out)
        self.assertNotIn("a/b/a/b/", out)
        self.assertNotIn('class="toctree-l1 current current-page"', out)

    def test_nav_assets_carry_every_variant_and_the_script(self) -> None:
        variants = {"<tree a>": 0, "<tree b>": 1}
        assets = gen_docs._nav_assets(variants)
        rels = {rel: body for rel, _, body in assets}
        self.assertEqual(rels[f"{gen_docs.NAV_DIR}/0.html"], "<tree a>")
        self.assertEqual(rels[f"{gen_docs.NAV_DIR}/1.html"], "<tree b>")
        self.assertIn(gen_docs.NAV_SCRIPT, rels)
        # The script is bundled verbatim from resources/, never inlined here.
        self.assertEqual(rels[gen_docs.NAV_SCRIPT],
                         gen_docs.NAV_SCRIPT_SRC.read_text(encoding="utf-8"))
        # It is authored project code, so it must live under resources/js/:
        # the SBOM asset scan reads the resources/ root as vendored libraries
        # and resources/js/ as the project's own modules.
        self.assertEqual(gen_docs.NAV_SCRIPT_SRC.parent.name, "js")
        self.assertEqual(gen_docs.NAV_SCRIPT_SRC.parent.parent.name,
                         "resources")

    def test_nav_stub_points_at_the_script_from_its_own_depth(self) -> None:
        # A page two directories deep needs ../../_static/... to reach the
        # script, and a top-level page just the plain path.
        block = gen_docs._SIDEBAR_START + "</div>"
        deep = gen_docs._nav_stub(block, "a/b/page.html", {})
        self.assertIn("../" * 2 + gen_docs.NAV_SCRIPT, deep)
        self.assertIn('data-nav="0"', deep)
        self.assertNotIn("../" * 3, deep)
        top = gen_docs._nav_stub(block, "page.html", {})
        self.assertIn('"' + gen_docs.NAV_SCRIPT + '"', top)
        self.assertNotIn("../", top)

    def test_injector_reveals_the_open_entry_in_the_drawer(self) -> None:
        # Regression for the invisible open entry: the tree is 60-odd entries
        # tall, so the entry a reader clicks sits below the drawer's fold on
        # the page it lands on.  Furo reveals its right-hand TOC only, so the
        # injector must reveal the entry it just marked -- and only in the
        # drawer: scrollIntoView (or a window scroll) would move the page.
        script = gen_docs.NAV_SCRIPT_SRC.read_text(encoding="utf-8")
        self.assertIn("reveal(mark(el))", script)
        self.assertIn('link.closest(".sidebar-scroll")', script)
        self.assertIn("box.scrollTop", script)
        # Furo's smooth scrolling must be overridden for the write: a smooth
        # reveal starts seconds late on a heavy page, i.e. after the reader
        # already sees a drawer that never moved.
        self.assertIn('box.style.scrollBehavior = "auto"', script)
        self.assertNotIn("scrollIntoView", script)
        self.assertNotIn("window.scroll", script)
        self.assertNotIn("documentElement.scrollTop", script)


class TestGenDocsBundling(unittest.TestCase):
    """The clean-build stamp and write-on-change guards (1.50.0).

    Regression cover for the stale-page bug: the bundled manual used to be
    collected from an incremental Sphinx build directory, so pages left dead
    by a rename stayed in the bundle.  A developer tree produced 217 assets
    and a fresh clone 204, and the changed spec invalidated the cached SPARK
    proof.  A build is now reused only when the docs-source digests, the
    fingerprint and the built file list all match, a changed tree rebuilds
    incrementally (sweeping what a removed source left and rewiring the nav
    when a page moved), and the spec is written only on a change.
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.docs = root / "docs"
        self.build = self.docs / "_build" / "html"
        self.stamp = self.docs / "_build" / ".adacovex-docs-sources"
        self.docs.mkdir(parents=True)
        self.build.mkdir(parents=True)
        (self.docs / "index.md").write_text("# index\n", encoding="utf-8")
        (self.build / "index.html").write_text("<html></html>",
                                              encoding="utf-8")
        self._saved = (gen_docs.DOCS, gen_docs.BUILD, gen_docs.STAMP)
        gen_docs.DOCS, gen_docs.BUILD, gen_docs.STAMP = (
            self.docs, self.build, self.stamp)

    def tearDown(self) -> None:
        gen_docs.DOCS, gen_docs.BUILD, gen_docs.STAMP = self._saved
        self._tmp.cleanup()

    def test_fingerprint_tracks_sources_not_build_output(self) -> None:
        digests = gen_docs.docs_source_digests()
        first = gen_docs.tree_fingerprint(digests)
        # A build product never moves the fingerprint ...
        (self.build / "stale.html").write_text("stale", encoding="utf-8")
        self.assertEqual(
            gen_docs.tree_fingerprint(gen_docs.docs_source_digests()), first)
        # ... a docs source change does.
        (self.docs / "index.md").write_text("# changed\n", encoding="utf-8")
        self.assertNotEqual(
            gen_docs.tree_fingerprint(gen_docs.docs_source_digests()), first)

    def test_a_stale_build_page_forces_a_clean_rebuild(self) -> None:
        digests = gen_docs.docs_source_digests()
        fp = gen_docs.tree_fingerprint(digests)
        self.assertFalse(gen_docs.build_is_current(fp, digests))  # no stamp
        gen_docs.write_stamp(fp, digests)
        self.assertTrue(gen_docs.build_is_current(fp, digests))
        # The 13-dead-pages bug: an extra page in the build output must not
        # be reused (it would ship in the bundle as a stale page).
        stale = self.build / "contributing" / "perf.html"
        stale.parent.mkdir()
        stale.write_text("<html>dead</html>", encoding="utf-8")
        self.assertFalse(gen_docs.build_is_current(fp, digests))

    def test_bundled_sidebar_stores_inner_markup_only(self) -> None:
        # Regression for the overflowing sidebar: the stub must keep the
        # .sidebar-container element and the shared _nav asset must carry only
        # its inner markup.  A stored container nests a second one on
        # injection, which collapses the sticky element's containing block to
        # 100vh: the sidebar then scrolls away with the page instead of
        # sticking with its own scrollbar (the built-in Furo behaviour).
        page = ('<html><body>'
                + gen_docs._SIDEBAR_START
                + '<div class="sidebar-sticky"><div class="sidebar-scroll">'
                  '<a href="index.html">Home</a></div></div></div>'
                + '<article>body</article></body></html>')
        (self.build / "index.html").write_text(page, encoding="utf-8")
        rels = {rel: body for rel, _, body in gen_docs.collect_assets(self.build)}
        # The page carries exactly one container, as the stub's own class.
        self.assertEqual(rels["index.html"].count('class="sidebar-container"'),
                         1)
        self.assertIn('data-nav="0"', rels["index.html"])
        # The stored tree is the container's inner markup: no wrapper, so the
        # injected tree cannot nest a second container.
        stored = rels[f"{gen_docs.NAV_DIR}/0.html"]
        self.assertNotIn("sidebar-container", stored)
        self.assertIn("sidebar-sticky", stored)
        self.assertIn("sidebar-scroll", stored)

    def test_generate_writes_the_spec_only_on_change(self) -> None:
        out = self.docs / "adacovex-docs_template.ads"
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("first", "stats")):
            with contextlib.redirect_stdout(io.StringIO()):
                gen_docs.generate(out)
        self.assertEqual(out.read_text(encoding="ascii"), "first")
        os.utime(out, (1_000_000, 1_000_000))
        before = out.stat().st_mtime_ns
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("first", "stats")):
            with contextlib.redirect_stdout(io.StringIO()):
                gen_docs.generate(out)
        self.assertEqual(out.stat().st_mtime_ns, before,
                         "an unchanged spec must not be rewritten")
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("second", "stats")):
            with contextlib.redirect_stdout(io.StringIO()):
                gen_docs.generate(out)
        self.assertEqual(out.read_text(encoding="ascii"), "second")

    def test_check_is_read_only(self) -> None:
        out = self.docs / "adacovex-docs_template.ads"
        out.write_text("committed", encoding="ascii")
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("different", "stats")):
            with contextlib.redirect_stdout(io.StringIO()):
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertFalse(gen_docs.check(out))
        self.assertEqual(out.read_text(encoding="ascii"), "committed",
                         "--check must never rewrite the committed spec")
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("committed", "stats")):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertTrue(gen_docs.check(out))


class TestCheckDocs(unittest.TestCase):
    """Pure-logic tests for tools/check-docs.py (docs gate + loc opt-out)."""

    def setUp(self) -> None:
        self._root = check_docs.ROOT

    def tearDown(self) -> None:
        check_docs.ROOT = self._root

    def _check(self, tmp: str, text: str) -> Tuple[List[str], str]:
        # check() resolves the path against ROOT; point it at the temp dir.
        check_docs.ROOT = Path(tmp)
        p = Path(tmp) / "page.md"
        p.write_text(text, encoding="utf-8")
        with contextlib.redirect_stderr(io.StringIO()) as err:
            errors = check_docs.check(p)
        return errors, err.getvalue()

    def test_loc_cap_warns_without_marker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            _, err = self._check(tmp, "# Page\n\n" + "- bullet\n" * 260)
            self.assertIn("lines (maximum", err)

    def test_loc_cap_opted_out_with_marker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            errors, err = self._check(
                tmp, "<!-- no-covex-docs-loc: reference dictionary -->\n"
                     "# Page\n\n" + "- bullet\n" * 260)
            self.assertEqual(errors, [])
            self.assertEqual(err, "")

    def test_marker_only_scanned_near_top(self) -> None:
        # A marker beyond the scan window does not opt the file out.
        with tempfile.TemporaryDirectory() as tmp:
            filler = "\n" * (check_docs.LOC_MARKER_SCAN + 5)
            _, err = self._check(
                tmp, "# Page" + filler + "<!-- no-covex-docs-loc -->\n"
                     + "- bullet\n" * 260)
            self.assertIn("lines (maximum", err)

    def test_paragraph_cap_still_hard_under_marker(self) -> None:
        # The opt-out covers the line cap only; the paragraph rule stays a
        # hard error even in an opted-out page.
        with tempfile.TemporaryDirectory() as tmp:
            errors, _ = self._check(
                tmp, "<!-- no-covex-docs-loc -->\n# Page\n\n"
                     "One. Two. Three. Four. Five.\n")
            self.assertEqual(len(errors), 1)
            self.assertIn("5 sentences", errors[0])

    def test_two_spaces_after_a_sentence_is_flagged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            errors, _ = self._check(tmp, "# Page\n\nOne.  Two.\n")
            self.assertEqual(len(errors), 1)
            self.assertIn("two spaces after a sentence", errors[0])

    def test_single_space_after_a_sentence_is_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            errors, _ = self._check(tmp, "# Page\n\nOne. Two.  Three.\n")
            # `Two.  Three` is still a double space; only a fully single-spaced
            # line passes.
            self.assertEqual(len(errors), 1)
            errors, _ = self._check(tmp, "# Page\n\nOne. Two. Three.\n")
            self.assertEqual(errors, [])

    def test_hard_break_and_ada_prefix_are_not_flagged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            # A markdown hard break is a trailing double space (no next
            # character), and the Ada docstring prefix in a code span is not
            # sentence punctuation.
            errors, _ = self._check(
                tmp, "# Page\n\nA hard break follows.  \nnext line.\n"
                     "Use ``--  `` as the comment prefix.\n")
            self.assertEqual(errors, [])

    def test_fixer_collapses_and_agrees_with_the_gate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            check_docs.ROOT = Path(tmp)
            docs = Path(tmp) / "docs"
            docs.mkdir()
            page = docs / "page.md"
            page.write_text("# Page\n\nOne.  Two.  Three.\n", encoding="utf-8")
            rel = page.relative_to(check_docs.ROOT)
            before = check_docs.spacing_errors(
                rel, page.read_text(encoding="utf-8").splitlines())
            self.assertTrue(before, "the gate must flag the double spaces")
            with contextlib.redirect_stdout(io.StringIO()):
                check_docs.fix()
            self.assertEqual(page.read_text(encoding="utf-8"),
                             "# Page\n\nOne. Two. Three.\n")
            after = check_docs.spacing_errors(
                rel, page.read_text(encoding="utf-8").splitlines())
            self.assertEqual(after, [])
            # The fixer is idempotent.
            with contextlib.redirect_stdout(io.StringIO()):
                check_docs.fix()
            self.assertEqual(page.read_text(encoding="utf-8"),
                             "# Page\n\nOne. Two. Three.\n")

    def test_ada_comment_double_space_is_flagged(self) -> None:
        errors = check_docs.source_spacing_errors(
            "src/x.ads", ["   --  One.  Two.",
                          "   A : constant := 1;",
                          "   B : Integer := 1;  --  Three.  Four."])
        self.assertEqual(len(errors), 2)
        self.assertIn("src/x.ads:1", errors[0])
        self.assertIn("src/x.ads:3", errors[1])

    def test_ada_code_and_string_literals_are_not_flagged(self) -> None:
        # Code alignment, and a `--` inside a string literal, are not prose.
        errors = check_docs.source_spacing_errors(
            "src/x.adb",
            ['   S : String := "One.  Two.";',
             '   S2 : String := "-- not a comment";',
             "   A : Integer := 1;  --  clean comment"])
        self.assertEqual(errors, [])

    def test_ada_comment_start_tracks_string_state(self) -> None:
        self.assertEqual(check_docs.ada_comment_start("   --  doc"), 3)
        self.assertEqual(
            check_docs.ada_comment_start('   S : String := "-- x";'), -1)
        self.assertEqual(
            check_docs.ada_comment_start('   S : String := "a""b";  --  c'), 26)
        self.assertEqual(check_docs.ada_comment_start("   plain code"), -1)

    def test_ada_fixer_keeps_the_code_byte_for_byte(self) -> None:
        text = ('   A : constant := 1;  --  One.  Two.\n'
                '   --  Three.  Four.\n'
                '   B : Integer := 2;\n')
        self.assertEqual(
            check_docs.collapse_comment_spaces(text),
            '   A : constant := 1;  --  One. Two.\n'
            '   --  Three. Four.\n'
            '   B : Integer := 2;\n')

    def test_collapse_touches_only_the_sentence_gap(self) -> None:
        # The pure normaliser behind the fixer: indentation, a markdown hard
        # break, and a fenced block all stay byte-for-byte as they were.
        text = ("One.  Two.\n"
                "Indent:  keep.\n"
                "Hard break.  \n"
                "```\nCode.  Keep.\n```\n")
        self.assertEqual(
            check_docs.collapse_sentence_spaces(text),
            "One. Two.\nIndent:  keep.\nHard break.  \n```\nCode.  Keep.\n```\n")


class TestCheckDocsCoverage(unittest.TestCase):
    """The documentation-coverage gate (tools/check-docs-coverage.py).

    The gate turns the manual CLI-reference / dashboard audit into a check:
    every CLI flag, every server route, and every hand-written usage or
    contributing page must be covered by the user documentation.
    """

    def test_flag_documented_accepts_both_spellings(self) -> None:
        docs = "Use `--target=PATH`. Run `status` for the toolchain."
        self.assertTrue(check_docs_coverage._flag_documented("target", docs))
        # A bare subcommand word, in backticks, counts too.
        self.assertTrue(check_docs_coverage._flag_documented("status", docs))
        self.assertFalse(check_docs_coverage._flag_documented("serve", docs))
        # A prefix of another flag must not count as documented.
        self.assertFalse(check_docs_coverage._flag_documented("tar", docs))

    def test_route_paths_normalise_the_trailing_slash(self) -> None:
        routes = check_docs_coverage.route_paths()
        # `/docs/` and `/docs` reach the same handler, so the set holds the
        # canonical form and the dashboard table needs one row.
        self.assertIn("/docs", routes)
        self.assertNotIn("/docs/", routes)
        self.assertIn("/", routes)
        for expected in ("/api/metrics", "/api/deps", "/api/endpoints",
                         "/badge/spark.svg", "/badge/tests.svg",
                         "/badge/do178c.svg", "/badge/iso26262.svg",
                         "/badge/iec62304.svg"):
            self.assertIn(expected, routes)

    def test_the_standards_split_pages_are_reachable(self) -> None:
        # The new category pages must be named by a {toctree} in
        # docs/index.md, or the sidebar never shows them.
        entries = check_docs_coverage.toctree_entries()
        for docname in ("usage/standards", "usage/standards-do-178c",
                        "usage/standards-iso-26262",
                        "usage/standards-iec-62304",
                        "usage/standards-selection"):
            self.assertIn(docname, entries)
        # The performance pages moved to their own category, and the
        # benchmarks page split into a sub-category.
        for docname in ("contributing/perf/index",
                        "contributing/perf/benchmarks",
                        "contributing/perf/benchmarks-timings",
                        "contributing/perf/benchmarks-binary-size",
                        "contributing/perf/benchmarks-server",
                        "contributing/perf/prove-timing"):
            self.assertIn(docname, entries)
        # The architecture, proving, and STE100 pages each have a category.
        for docname in ("contributing/architecture",
                        "contributing/architecture-pipeline",
                        "contributing/proving",
                        "contributing/proving-patches",
                        "contributing/ste100/index",
                        "contributing/ste100/concepts"):
            self.assertIn(docname, entries)

    def test_index_toctree_entries_all_resolve(self) -> None:
        # A dangling entry (the `HLR` / `LLR` case: the pages live at
        # compliance/HLR.md) makes Sphinx report `toc.not_readable`, and the
        # sidebar silently drops the page.
        self.assertEqual(check_docs_coverage.missing_toctree_targets(), [])
        entries = check_docs_coverage.toctree_entries()
        self.assertIn("compliance/HLR", entries)
        self.assertIn("compliance/LLR", entries)

    def test_the_current_tree_passes_the_gate(self) -> None:
        # The real tree is the fixture: every flag, route, and page is
        # covered.
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check_docs_coverage.check(), 0)


class TestCheckBookLinks(unittest.TestCase):
    """Pure-logic tests for tools/check-book-links.py (book drift + links)."""

    def test_internal_targets_resolves_relative(self) -> None:
        html = '<a href="../architecture.html">arch</a>'
        self.assertEqual(check_book_links.internal_targets(html, "api-docs/index.html"),
                         ["architecture.html"])

    def test_internal_targets_strips_anchor_and_query(self) -> None:
        html = '<a href="dashboard.html#charts">c</a> <a href="sbom.html?x=1">s</a>'
        self.assertEqual(check_book_links.internal_targets(html, "index.html"),
                         ["dashboard.html", "sbom.html"])

    def test_internal_targets_skips_external(self) -> None:
        html = ('<a href="https://example.com/x">e</a> '
                '<a href="mailto:a@b.c">m</a> '
                '<a href="data:text/plain,x">d</a> '
                '<a href="//cdn.example/x">p</a> '
                '<a href="#local">a</a>')
        self.assertEqual(check_book_links.internal_targets(html, "index.html"), [])

    def test_bundle_links_ok(self) -> None:
        assets = [("index.html", "text/html",
                   '<a href="architecture.html">a</a><a href="#top">t</a>'),
                  ("architecture.html", "text/html", "<p>arch</p>")]
        self.assertEqual(check_book_links.check_bundle_links(assets), [])

    def test_bundle_links_broken_detected(self) -> None:
        assets = [("index.html", "text/html",
                   '<a href="missing.html">m</a>'),
                  ("architecture.html", "text/html", "<p>arch</p>")]
        errors = check_book_links.check_bundle_links(assets)
        self.assertEqual(len(errors), 1)
        self.assertIn("missing.html", errors[0])

    def test_bundle_links_tolerates_excluded_prefix(self) -> None:
        # _sources/ and _images/ are deliberately not bundled; a link to them
        # in a produced page must not fail the check.  A subpage references
        # them with a leading ../ (matching real Sphinx output), and the
        # _downloads/ badge SVG resolves to a bundled asset.
        html = ('<a href="../_sources/usage/dashboard.md.txt">src</a> '
                '<img src="../_images/dashboard_preview_overview.png"> '
                '<a href="../_downloads/spark.svg">badge</a>')
        assets = [("usage/dashboard.html", "text/html", html),
                  ("_downloads/spark.svg", "image/svg+xml", "<svg/>")]
        self.assertEqual(check_book_links.check_bundle_links(assets), [])

    def test_bundle_links_resolves_sphinx_rooted_paths(self) -> None:
        # A theme can link the top of the TOC as an absolute root-relative
        # path (href="/index.html"), which must resolve against the bundled
        # root regardless of the current page's depth.
        assets = [("usage/dashboard.html", "text/html",
                   '<a href="/index.html">home</a>'
                   '<a href="../index.html">i</a>'),
                  ("index.html", "text/html", "<p>home</p>")]
        self.assertEqual(check_book_links.check_bundle_links(assets), [])

    def test_fresh_build_produces_whole_book(self) -> None:
        # The link check runs against a fresh temp build (docs/_build/html is
        # a local, gitignored product): a stale local build must never mask a
        # broken link.  Requires sphinx-build, exactly like the gate itself.
        if gen_docs.sphinx_build_cmd() is None:
            self.skipTest("sphinx-build not resolvable (PATH or .venv)")
        with tempfile.TemporaryDirectory(prefix="adacovex-book-") as td:
            dest = Path(td)
            self.assertTrue(check_book_links.sphinx_build_into(dest))
            out = dest / "out"
            self.assertTrue((out / "index.html").is_file())
            self.assertTrue((out / "searchindex.js").is_file())
            # The fresh build carries the same self-contained link surface.
            assets = gen_docs.collect_assets(out)
            self.assertEqual(check_book_links.check_bundle_links(assets), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
