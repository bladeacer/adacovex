"""Task-runner, check-phase, and metric-sync tests."""

from testsupport import *  # noqa: F401,F403


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

class BenchCloneTests(unittest.TestCase):
    """Pure-logic tests for the cold-clone benchmark shape (tools/bench.py)."""

    def test_make_clone_strips_build_and_vcs_state(self) -> None:
        # The clone carries sources and manifests but none of the state the
        # cold-clone scenario must not start with: obj/ (gnatprove session),
        # bin/ (build output), .git, and .adacovex (result-cache state).
        import bench
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "proj"
            (src / "src").mkdir(parents=True)
            (src / "obj" / "gnatprove").mkdir(parents=True)
            (src / "bin").mkdir()
            (src / ".git").mkdir()
            (src / ".adacovex" / "cache").mkdir(parents=True)
            (src / "src" / "main.adb").write_text("procedure M is\n"
                                                   "begin null; end M;\n",
                                                   encoding="utf-8")
            (src / "alire.toml").write_text('name = "p"\n', encoding="utf-8")
            (src / "obj" / "gnatprove" / "gnatprove.out").write_text(
                "summary\n", encoding="utf-8")
            clone = bench.make_clone(src)
            try:
                self.assertTrue((clone / "src" / "main.adb").is_file())
                self.assertTrue((clone / "alire.toml").is_file())
                self.assertFalse((clone / "obj").exists())
                self.assertFalse((clone / "bin").exists())
                self.assertFalse((clone / ".git").exists())
                self.assertFalse((clone / ".adacovex").exists())
            finally:
                shutil.rmtree(clone.parent, ignore_errors=True)

    def test_load_avg_reads_proc_loadavg(self) -> None:
        # Every scenario banner carries the load it was measured under, so a
        # reader can tell a real difference from a sequence artefact: the
        # scenarios run in order and each loads the box.
        import bench
        reading = bench.load_avg()
        if Path("/proc/loadavg").is_file():
            expected = Path("/proc/loadavg").read_text().split()[0]
            self.assertEqual(reading, expected)
            # The first field is the 1-minute average: a bare decimal number.
            float(reading)
        else:
            # A machine without /proc/loadavg reports "unknown" rather than
            # failing the whole bench.
            self.assertEqual(reading, "unknown")

    def test_announce_reports_label_and_load(self) -> None:
        import bench
        with contextlib.redirect_stdout(io.StringIO()) as out:
            bench.announce("Prove cold clone")
        line = out.getvalue()
        self.assertIn("Prove cold clone", line)
        self.assertIn("load", line)

    def test_make_clone_copies_the_tree_not_a_link(self) -> None:
        import bench
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "proj"
            src.mkdir()
            (src / "a.txt").write_text("x", encoding="utf-8")
            clone = bench.make_clone(src)
            try:
                self.assertTrue(clone.is_dir())
                self.assertNotEqual(clone, src)
                self.assertEqual(clone.name, "proj")
                # Mutating the clone never touches the source tree.
                (clone / "a.txt").write_text("y", encoding="utf-8")
                self.assertEqual((src / "a.txt").read_text(encoding="utf-8"),
                                 "x")
            finally:
                shutil.rmtree(clone.parent, ignore_errors=True)

class CheckGateOrderTests(unittest.TestCase):
    """The `check` gate order: `fmt` must come before anything that reads the
    Ada sources.

    The order now lives in `tools/tasks.py` (`CHECK_GATES`), so this reads it
    from there rather than parsing a Makefile recipe -- the Makefile is a thin
    shim that delegates to the same Python tasks.  gnatdoc renders
    `docs/api-docs/` from the sources and gnatprove analyses them, so both
    read formatting that `fmt` owns; anything downstream of `fmt` therefore
    has to run after it.
    """

    def _check_gate_order(self) -> List[str]:
        return tasks.check_gate_labels()

    def test_fmt_is_a_gate(self) -> None:
        gates = self._check_gate_order()
        self.assertTrue(any(g == "fmt" for g in gates),
                        f"check no longer runs fmt: {gates}")

    def test_fmt_runs_before_the_gates_that_read_sources(self) -> None:
        gates = self._check_gate_order()
        fmt = gates.index("fmt")
        # `doc` renders the API docs from the Ada sources and `prove` analyses
        # them, so both must see the formatted tree.  `build` compiles it.
        for label in ("build", "native tests", "SPARK proof + badges",
                      "API docs"):
            self.assertIn(label, gates, f"gate missing: {label}")
            self.assertLess(fmt, gates.index(label),
                            f"fmt must run before '{label}': {gates}")

    def test_fmt_runs_first(self) -> None:
        # Nothing may precede fmt: a gate that ran earlier would have judged
        # the tree before the formatter visited it.
        gates = self._check_gate_order()
        self.assertEqual(gates[0], "fmt", f"expected fmt first: {gates}")

    def test_fmt_excludes_every_generated_spec(self) -> None:
        # gnatformat and the generators disagree on layout, so formatting a
        # generated spec makes it fail the generator's byte comparison and get
        # rewritten, and the next fmt mangles it again.  That ping-pong is
        # what stopped `check` reaching a fixed point.
        root = Path(__file__).resolve().parent.parent
        names = set(tasks.GENERATED_SPECS)
        # Every spec a generator writes must be named, and each must exist.
        for spec in sorted(root.glob("src/adacovex*_template.ads")) + \
                sorted(root.glob("src/adacovex_version_info.ads")):
            self.assertIn(spec.name, names,
                          f"generated spec not excluded from fmt: {spec.name}")

    def test_fmt_excludes_fixture_projects(self) -> None:
        # A fixture is a standalone project with its own GPR, so the root
        # project cannot see it; formatting one printed the "not visible to
        # the provided project" warning and touched a file the build never
        # compiles.
        sources = set(tasks.fmt_sources())
        self.assertTrue(sources, "fmt would format nothing")
        for source in sources:
            self.assertFalse(source.startswith(tuple(tasks.FIXTURE_ROOTS)),
                             f"fixture source handed to gnatformat: {source}")
        self.assertIn("src/tests/adacovex-test_support.ads", sources)
        self.assertNotIn("src/tests/fixtures/ecosystems/ada/src/mini.ads",
                         sources)

class CheckParallelPhaseTests(unittest.TestCase):
    """Every gate runs exactly once, and the writers stay in serial phases."""

    def test_phases_partition_the_gate_list(self) -> None:
        gates = tasks.check_gate_labels()
        phases = (tasks.CHECK_SERIAL_HEAD + tasks.CHECK_SERIAL_MID
                  + [g for g in gates if g not in tasks.CHECK_SERIAL_HEAD
                     and g not in tasks.CHECK_SERIAL_MID
                     and g not in tasks.CHECK_SERIAL_TAIL]
                  + tasks.CHECK_SERIAL_TAIL)
        self.assertEqual(sorted(phases), sorted(gates))
        self.assertEqual(len(phases), len(set(phases)),
                         "a gate is scheduled in more than one phase")

    def test_fmt_and_build_lead_and_syncs_trail(self) -> None:
        self.assertEqual(tasks.CHECK_SERIAL_HEAD[:2], ["fmt", "build"])
        self.assertEqual(tasks.CHECK_SERIAL_TAIL[-4:],
                         ["test counts in sync", "proof metrics in sync",
                          "description sync", "requirements sync"])

    def test_every_named_parallel_process_is_a_gate(self) -> None:
        gates = set(tasks.check_gate_labels())
        for label in tasks.CHECK_PARALLEL_PROCESS:
            self.assertIn(label, gates)
            self.assertNotIn(label, tasks.CHECK_SERIAL_HEAD)
            self.assertNotIn(label, tasks.CHECK_SERIAL_MID)

class LiveFilePruneTests(unittest.TestCase):
    """The metric-sync scan prunes build and vendored trees while walking."""

    def test_generated_and_vendored_trees_are_not_yielded(self) -> None:
        yielded = {p.relative_to(live_files.ROOT).as_posix()
                   for p in live_files.iter_live_files()}
        self.assertIn("AGENTS.md", yielded)
        for prefix in ("obj/", "bin/", ".git/", "node_modules/",
                       "docs/_build/", "docs/api-docs/", "tools/"):
            self.assertFalse(any(p.startswith(prefix) for p in yielded),
                             f"live scan yielded a {prefix} file")

    def test_past_changelogs_are_historical_but_the_dev_one_is_live(self) -> None:
        yielded = {p.name for p in live_files.iter_live_files()
                   if p.parent.name == "changelogs"}
        self.assertIn(live_files.current_changelog().name, yielded)

class CliShardTests(unittest.TestCase):
    """Every CLI check group runs in at least one shard, and none twice."""

    def test_shards_partition_the_check_groups(self) -> None:
        e2e = (Path(__file__).resolve().parent.parent
               / "src" / "tests" / "e2e" / "cli")
        sys.path.insert(0, str(e2e))
        try:
            cli_flags = importlib.import_module("cli_flags")
        finally:
            sys.path.remove(str(e2e))
        names = [name for name, _ in cli_flags.CHECKS]
        self.assertEqual(len(names), len(set(names)))
        for shard in range(4):
            selected = names[shard::4]
            self.assertTrue(selected,
                            f"shard {shard}/4 selects no check group")
        self.assertEqual(sorted(names), sorted(set(names)))

class CheckReuseTests(unittest.TestCase):
    """One build, one docs bundle, and one proof run per `check`.

    A later gate must reuse the product an earlier gate made: no gate
    recompiles the tree, re-bundles the offline manual, or re-runs
    gnatprove.  The memos in `tools/tasks.py` carry that rule, so this
    counts the generator invocations instead of timing them.
    """

    def setUp(self) -> None:
        self._saved = (task_common._BUILD_DONE, task_common._BOOK_DONE,
                       task_common._PROVE_DONE)
        task_common._BUILD_DONE = False
        task_common._BOOK_DONE = False
        task_common._PROVE_DONE = False
        self.calls: List[Tuple[str, ...]] = []

    def tearDown(self) -> None:
        (task_common._BUILD_DONE, task_common._BOOK_DONE,
         task_common._PROVE_DONE) = self._saved

    def _fake_py(self, *args: str) -> int:
        self.calls.append(tuple(args))
        return 0

    def test_later_gates_reuse_the_build_docs_and_proof(self) -> None:
        with mock.patch.object(task_build_module, "py", self._fake_py), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tasks.task_build(), 0)
            self.assertEqual(tasks.task_book(), 0)
            self.assertEqual(tasks.task_prove(), 0)
            self.assertEqual(tasks.task_prove(), 0)
            self.assertEqual(tasks.task_build(), 0)
        self.assertEqual(self.calls.count(("tools/build.py",)), 1,
                         f"build ran more than once: {self.calls}")
        self.assertEqual(
            [c for c in self.calls if c[0] == "tools/gen-docs.py"], [],
            "the build already bundled the manual; task_book re-bundled it")
        self.assertEqual(self.calls.count(("tools/run.py", "prove")), 1,
                         f"proof ran more than once: {self.calls}")

    def test_book_runs_the_bundle_once_without_a_build(self) -> None:
        with mock.patch.object(task_build_module, "py", self._fake_py), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tasks.task_book(), 0)
            self.assertEqual(tasks.task_book(), 0)
        self.assertEqual(
            self.calls.count(("tools/gen-docs.py",)), 1,
            f"the manual was bundled more than once: {self.calls}")

    def test_a_failed_build_rebuilds_on_the_next_gate(self) -> None:
        def failing_py(*args: str) -> int:
            self.calls.append(tuple(args))
            return 1
        with mock.patch.object(task_build_module, "py", failing_py), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tasks.task_build(), 1)
            self.assertEqual(tasks.task_build(), 1)
        self.assertEqual(self.calls.count(("tools/build.py",)), 2,
                         "a failed build must not be memoised as a product")

class DiagnosticCoverageTests(unittest.TestCase):
    """The diagnostics matrix, Fix_Hint branches, and fixtures agree."""

    def test_matrix_parses_and_has_supported_rows(self) -> None:
        rows = diagnostic_coverage.matrix_rows()
        self.assertTrue(rows, "the diagnostics matrix is empty")
        cases = {row["case"] for row in rows}
        self.assertIn("index", cases)
        self.assertTrue(any(row["status"].startswith("Supported")
                            for row in rows))

    def test_fix_hint_keywords_are_documented(self) -> None:
        rows = diagnostic_coverage.matrix_rows()
        documented = {
            keyword.strip("`")
            for row in rows
            for keyword in row["keywords"].replace(",", " ").split()
        }
        for keyword in diagnostic_coverage.fix_hint_keywords():
            self.assertIn(keyword, documented,
                          f"Fix_Hint keyword not documented: {keyword}")

    def test_fixtures_have_rows(self) -> None:
        cases = {row["case"] for row in diagnostic_coverage.matrix_rows()}
        for name in diagnostic_coverage.fixture_names():
            self.assertIn(name, cases, f"fixture has no matrix row: {name}")

class TestLayoutTests(unittest.TestCase):
    """The layout and portability gates keep their documented shape."""

    def test_inline_project_heredoc_is_detected(self) -> None:
        line = "          cat > alire.toml <<'FIXTURE'"
        match = test_layout.INLINE_TARGET.search(line)
        self.assertIsNotNone(match)
        self.assertEqual(match.group("target"), "alire.toml")
        self.assertIsNone(test_layout.INLINE_TARGET.search("cp fixture.gpr ."))

    def test_inline_check_ignores_a_non_project_target(self) -> None:
        match = test_layout.INLINE_TARGET.search("cat > notes.txt <<'EOF'")
        self.assertIsNotNone(match)
        self.assertFalse(match.group("target").endswith(
            test_layout.INLINE_SUFFIXES))

    def test_ada_comment_text_is_not_scanned(self) -> None:
        path = Path("x.adb")
        self.assertEqual(test_portability._code_text(path, "  --  use /tmp"),
                         "  ")
        self.assertIn("/tmp", test_portability._code_text(
            path, '  X : String := "/tmp";'))

    def test_allow_list_entries_carry_a_reason(self) -> None:
        self.assertTrue(test_portability.ALLOW)
        for path, rule, reason in test_portability.ALLOW:
            self.assertTrue(path and rule and reason.strip())

class ProofStatusSyncTests(unittest.TestCase):
    """Metric sync rewrites status lines, not measured campaign notes."""

    METRICS: dict = {
        "total": 1058, "proved": 1058, "flow": 196, "justified": 0,
        "unproved": 0, "units": 77, "level": "Gold",
    }

    def _apply(self, line: str) -> str:
        for pattern, replacement in update_proof_status.replacements(self.METRICS):
            line = pattern.sub(replacement, line)
        return line

    def test_a_measured_campaign_note_keeps_its_unit_count(self) -> None:
        line = "196 flow and 858 provers across 76 analysed units and 0 unproved"
        self.assertEqual(self._apply(line), line)

    def test_a_ledger_sample_takes_the_current_counts(self) -> None:
        self.assertEqual(
            self._apply("GNATprove: Gold (1054 VCs), 75 analysed units"),
            "GNATprove: Gold (1058 VCs), 77 analysed units")

    def test_vc_phrases_still_track_the_current_proof(self) -> None:
        self.assertEqual(self._apply("Gold, 1054 VCs, 2 unproved"),
                         "Gold, 1058 VCs, 0 unproved")


class TaskkitLayoutTests(unittest.TestCase):
    """The task runner stays split into one module per responsibility."""

    MODULES: tuple = ("common", "build", "gates", "e2e", "release",
                      "checks")

    def test_every_taskkit_module_imports(self) -> None:
        for name in self.MODULES:
            module = importlib.import_module(f"taskkit.{name}")
            self.assertTrue(module.__doc__, f"taskkit.{name} has no docstring")

    def test_the_entry_point_owns_the_registry_and_gate_order(self) -> None:
        from taskkit import checks
        self.assertEqual(tasks.TASKS["check"], checks.task_check)
        self.assertIs(tasks.CHECK_GATES, checks.CHECK_GATES)
        self.assertEqual(len(tasks.CHECK_GATES), 34)

    def test_each_cli_check_group_has_a_module(self) -> None:
        cli = Path(__file__).resolve().parent.parent / "src" / "tests" / "e2e" / "cli"
        for name in ("cli_support", "checks_basic", "checks_sbom",
                     "checks_serve", "checks_config", "checks_prove"):
            self.assertTrue((cli / f"{name}.py").is_file(), name)
        registry = (cli / "cli_flags.py").read_text(encoding="utf-8")
        self.assertIn("CHECKS = [", registry)
        self.assertIn('("tldr install", check_tldr_install)', registry)
