"""ASCII, developer-command, GNATprove-pin, run, and SPARK-off tests."""

from testsupport import *  # noqa: F401,F403


class TestAsciiCheck(unittest.TestCase):
    def test_repo_is_clean(self) -> None:
        self.assertEqual(ascii_check.bad_files(ascii_check.ROOT), [])

    def test_ascii_file_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            #  Write bytes, not text: Path.write_text translates \n to \r\n on
            #  Windows, and a carriage return is a violation by design.
            Path(tmp, "a.md").write_bytes(b"pure ascii\n")
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

    def _helper(self, body: str) -> str:
        """A Python one-shot the platform shell can run on any host."""
        helper = self._root / "helper.py"
        helper.write_text(body, encoding="utf-8")
        return f'"{sys.executable}" "{helper}"'

    def test_swap_and_restore(self) -> None:
        self._seed()
        out = self._root / "seen.txt"
        # Drive the command through Python: swap_and_run uses the platform
        # shell, and a `cat`/`>` chain is POSIX-only -- the test must mean
        # the same thing on Windows and on Linux.
        rc = dev_cmd.swap_and_run(
            self._helper(
                "from pathlib import Path\n"
                "Path('seen.txt').write_text("
                "Path('alire.toml').read_text(encoding='utf-8'), "
                "encoding='utf-8')\n"
                "Path('alire/settings.toml').write_text('changed\\n', "
                "encoding='utf-8')\n"
                "Path('alire/new.txt').write_text('extra\\n', encoding='utf-8')\n"
            ))
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
        rc = dev_cmd.swap_and_run(
            f'"{sys.executable}" -c "raise SystemExit(3)"')
        self.assertEqual(rc, 3)
        self.assertEqual((self._root / "alire.toml").read_text(encoding="utf-8"),
                         "regular\n")
        self.assertTrue((self._root / "alire" / "settings.toml").is_file())

    def test_created_alire_left_when_none_existed(self) -> None:
        (self._root / "alire.toml").write_text("regular\n", encoding="utf-8")
        (self._root / "alire-dev.toml").write_text("dev\n", encoding="utf-8")
        rc = dev_cmd.swap_and_run(
            f'"{sys.executable}" -c "from pathlib import Path; '
            "Path('alire').mkdir()\"")
        self.assertEqual(rc, 0)
        self.assertEqual((self._root / "alire.toml").read_text(encoding="utf-8"),
                         "regular\n")
        self.assertTrue((self._root / "alire").is_dir())

class TestGNATprovePin(unittest.TestCase):
    """The gnatprove pin is gated across the live CI/action sources (item 3)."""

    def setUp(self) -> None:
        self._orig = (check_version.ROOT, check_version.GNATPROVE_MANIFEST,
                      check_version.GATED_GNAT_FILES,
                      check_version.GNATPROVE_EXAMPLES)
        self._tmp = tempfile.TemporaryDirectory()
        check_version.ROOT = Path(self._tmp.name)
        check_version.GNATPROVE_MANIFEST = check_version.ROOT / "alire-dev.toml"
        check_version.GATED_GNAT_FILES = (
            check_version.ROOT / "action.yml",
            check_version.ROOT / ".github" / "workflows" / "ci.yml",
        )
        check_version.GNATPROVE_EXAMPLES = (
            check_version.ROOT / "src" / "core" / "adacovex-prove.ads",
            check_version.ROOT / "docs" / "api-docs" / "adacovex-prove.md",
        )
        self._seed()

    def tearDown(self) -> None:
        (check_version.ROOT, check_version.GNATPROVE_MANIFEST,
         check_version.GATED_GNAT_FILES,
         check_version.GNATPROVE_EXAMPLES) = self._orig
        self._tmp.cleanup()

    def _write(self, rel: str, text: str) -> None:
        path = check_version.ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def _seed(self, action: str = "16.1.0", workflow: str = "16.1.0",
              example: str = "^16.1.0") -> None:
        self._write("alire-dev.toml", 'gnatprove = "^16.1.0"\n')
        self._write("action.yml",
                    "  gnat-version:\n"
                    f"    default: '{action}'\n")
        self._write(".github/workflows/ci.yml",
                    f"          gnat-version: {workflow}\n")
        self._write("docs/proof/16.1.0-ledger.md", "# ledger\n")
        self._write("src/core/adacovex-prove.ads",
                    f"-- expression (`{example}`, `~16.1.0`)\n")
        self._write("docs/api-docs/adacovex-prove.md",
                    f"expression (``{example}``)\n")

    def test_consistent_pins_pass(self) -> None:
        self.assertEqual(check_version.check_gnatprove(), [])

    def test_drifted_workflow_fails(self) -> None:
        self._seed(workflow="15.1.0")
        problems = check_version.check_gnatprove()
        self.assertTrue(any("ci.yml" in p and "15.1.0" in p for p in problems))

    def test_drifted_action_default_fails(self) -> None:
        self._seed(action="15.1.0")
        problems = check_version.check_gnatprove()
        self.assertTrue(any("action.yml" in p for p in problems))

    def test_missing_ledger_fails(self) -> None:
        (check_version.ROOT / "docs" / "proof" / "16.1.0-ledger.md").unlink()
        problems = check_version.check_gnatprove()
        self.assertTrue(any("no proof ledger" in p for p in problems))

    def test_stale_example_fails(self) -> None:
        self._seed(example="^15.1.0")
        problems = check_version.check_gnatprove()
        self.assertTrue(any("^16.1.0" in p for p in problems))

    def test_history_is_never_gated(self) -> None:
        # A 15.1.0 pin in a dated record is correct history: the live pin set
        # never includes it, so it can never be flagged.
        self._write("docs/changelogs/adacovex-1.6.0.md", "gnatprove 15.1.0\n")
        self._write("index/ad/covex/covex-1.5.0.toml", 'gnatprove = "^15.1.0"\n')
        gated = {str(p.relative_to(check_version.ROOT))
                 for p in check_version.GATED_GNAT_FILES}
        for path in ("docs/changelogs/adacovex-1.6.0.md",
                     "index/ad/covex/covex-1.5.0.toml"):
            self.assertNotIn(path, gated)
        self.assertEqual(check_version.check_gnatprove(), [])

    def test_no_pin_reports_loudly(self) -> None:
        (check_version.ROOT / "alire-dev.toml").write_text(
            'version = "1.2.3"\n', encoding="utf-8")
        problems = check_version.check_gnatprove()
        self.assertTrue(any("no gnatprove pin" in p for p in problems))

class TestRun(unittest.TestCase):
    def test_assess_args_are_flags(self) -> None:
        flags = run.self_assess_args().split()
        self.assertTrue(len(flags) >= 5)
        for flag in flags:
            # Single -flag=value words (long or shorthand), so the string can
            # be shell-split without a value-arity table.
            self.assertTrue(flag.startswith("-"))
            self.assertIn("=", flag)
        self.assertIn("--spark=Gold", flags)
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

class SparkOffCheckTests(unittest.TestCase):
    """Pure-logic tests for tools/spark-off-check.py (the SPARK_Mode gate).

    The gate matches only the code part of an Ada line, so a docstring that
    names the pragma to document it is not a violation, while a real pragma
    or aspect still is.
    """

    def test_code_part_keeps_code_and_drops_comments(self) -> None:
        self.assertEqual(
            spark_off.code_part("   pragma SPARK_Mode (Off);"),
            "   pragma SPARK_Mode (Off);")
        self.assertEqual(
            spark_off.code_part("   pragma SPARK_Mode (Off);  --  why"),
            "   pragma SPARK_Mode (Off);  ")
        self.assertEqual(
            spark_off.code_part("   --  prose (SPARK_Mode => Off)"), "   ")

    def test_code_part_tracks_string_literals(self) -> None:
        # A `--` inside a literal is not a comment, so the pragma after it
        # is still code; the literal's contents are data and are dropped.
        self.assertEqual(
            spark_off.code_part('   S : constant String := "a--b";'),
            '   S : constant String := "";')
        self.assertEqual(
            spark_off.code_part('   X := "a--b"; pragma SPARK_Mode (Off);'),
            '   X := ""; pragma SPARK_Mode (Off);')
        # A fixture that only quotes the pragma is data, not a violation.
        self.assertNotIn(
            "pragma",
            spark_off.code_part('         ("   pragma SPARK_Mode (Off);"),'))
        # A doubled quote escapes one quote and the literal stays open.
        self.assertEqual(
            spark_off.code_part('   S : constant String := "a""--b";  --  x'),
            '   S : constant String := "";  ')

    def test_violations_flags_code_and_not_prose(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            core = root / "src" / "core"
            core.mkdir(parents=True)
            (core / "probe_prag.ads").write_text(
                "package P is\n"
                "   pragma SPARK_Mode (Off);\n"
                "end P;\n", encoding="utf-8")
            (core / "probe_aspect.ads").write_text(
                "package Q with SPARK_Mode => Off is\n"
                "end Q;\n", encoding="utf-8")
            (core / "probe_prose.ads").write_text(
                "package R is\n"
                "   --  the skipped line carries (SPARK_Mode => Off)\n"
                "end R;\n", encoding="utf-8")
            with mock.patch.object(spark_off, "ROOT", root), \
                 mock.patch.object(spark_off, "SRC", root / "src"):
                found = {(rel, int(lineno))
                         for rel, lineno, _ in spark_off.violations()}
        self.assertEqual(found,
                         {("src/core/probe_prag.ads", 2),
                          ("src/core/probe_aspect.ads", 1)})

    def test_exempt_packages_are_never_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            core = root / "src" / "core"
            core.mkdir(parents=True)
            for name in ("adacovex-types.ads", "adacovex-complexity.ads"):
                (core / name).write_text(
                    "package X is\n   pragma SPARK_Mode (Off);\nend X;\n",
                    encoding="utf-8")
            with mock.patch.object(spark_off, "ROOT", root), \
                 mock.patch.object(spark_off, "SRC", root / "src"):
                self.assertEqual(spark_off.violations(), [])

    def test_repo_tree_is_clean(self) -> None:
        # The gate must pass on the tree it guards, prose included.
        self.assertEqual([f"{rel}:{line}" for rel, line, _ in
                          spark_off.violations()], [])
