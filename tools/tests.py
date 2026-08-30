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
gen_docs = importlib.import_module("gen-docs")
import release
import run
import versions
import csslint
para_split = importlib.import_module("para-split")
rst2md = importlib.import_module("rst2md")
check_book_links = importlib.import_module("check-book-links")

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
    """Pure-logic tests for tools/para-split.py (the 4-sentence rule)."""
    def test_count_sentences(self) -> None:
        self.assertEqual(para_split._count_sentences("One. Two. Three. Four."),
                         4)
        # Decimals and abbreviations are not sentence breaks.
        self.assertEqual(para_split._count_sentences("v1.21.0 ships. e.g."),
                         1)
        self.assertEqual(para_split._count_sentences("No punctuation"), 0)

    def test_chunks_cap_at_four_preserve_text(self) -> None:
        text = "First. Second. Third. Fourth. Fifth. It ships 1.21.0."
        out = para_split._chunks(text)
        self.assertEqual(len(out), 2)
        self.assertIn("1.21.0", " ".join(out))
        for chunk in out:
            self.assertLessEqual(para_split._count_sentences(chunk), 4)

    def test_chunks_under_limit_unchanged(self) -> None:
        self.assertEqual(para_split._chunks("Just. Two. Sentences."),
                         ["Just. Two. Sentences."])

    def test_is_prose(self) -> None:
        self.assertFalse(para_split._is_prose("1. item"))
        self.assertFalse(para_split._is_prose("- item"))
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
