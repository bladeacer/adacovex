"""Documentation, terminology, and layout gate tests."""

from testsupport import *  # noqa: F401,F403


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

    def test_loc_cap_fails_without_marker(self) -> None:
        # The cap is a hard gate: an over-cap page with no opt-out is an error,
        # so `just docs-check` fails rather than printing a warning nobody acts
        # on.  The message names the marker a dated record can add instead.
        with tempfile.TemporaryDirectory() as tmp:
            errors, err = self._check(tmp, "# Page\n\n" + "- bullet\n" * 260)
            self.assertEqual(err, "")
            self.assertEqual(len(errors), 1)
            self.assertIn("lines (maximum", errors[0])
            self.assertIn("no-covex-docs-loc", errors[0])

    def test_loc_cap_opted_out_with_marker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            errors, err = self._check(
                tmp, "<!-- no-covex-docs-loc: reference dictionary -->\n"
                     "# Page\n\n" + "- bullet\n" * 260)
            self.assertEqual(errors, [])
            self.assertEqual(err, "")

    def test_marker_only_scanned_near_top(self) -> None:
        # A marker beyond the scan window does not opt the file out, so the
        # over-cap page still fails.
        with tempfile.TemporaryDirectory() as tmp:
            filler = "\n" * (check_docs.LOC_MARKER_SCAN + 5)
            errors, _ = self._check(
                tmp, "# Page" + filler + "<!-- no-covex-docs-loc -->\n"
                     + "- bullet\n" * 260)
            self.assertEqual(len(errors), 1)
            self.assertIn("lines (maximum", errors[0])

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

    def test_patch_files_are_in_scope(self) -> None:
        # .adacovex/patches/*.ads|adb join the rule's file set; a patch
        # docstring is prose exactly like a src/ docstring.
        with tempfile.TemporaryDirectory() as tmp:
            check_docs.ROOT = Path(tmp)
            patches = Path(tmp) / ".adacovex" / "patches"
            patches.mkdir(parents=True)
            self.assertEqual(check_docs.patch_files(), [])
            spec = patches / "vendored.ads"
            spec.write_text("package Vendored is\nend Vendored;\n",
                            encoding="utf-8")
            body = patches / "nested" / "vendored.adb"
            body.parent.mkdir()
            body.write_text("package body Vendored is\nend Vendored;\n",
                            encoding="utf-8")
            other = Path(tmp) / "docs" / "note.ads"
            other.parent.mkdir()
            other.write_text("package Note is\nend Note;\n", encoding="utf-8")
            found = check_docs.patch_files()
            self.assertEqual(sorted(found), sorted([spec, body]))
            # source_files() folds the patch set in.
            self.assertIn(spec, check_docs.source_files())

    def test_patch_comment_double_space_is_flagged_and_fixed(self) -> None:
        # The gate flags a double space after a sentence in patch comment
        # text, and --fix collapses it without touching the code.
        with tempfile.TemporaryDirectory() as tmp:
            check_docs.ROOT = Path(tmp)
            patches = Path(tmp) / ".adacovex" / "patches"
            patches.mkdir(parents=True)
            spec = patches / "vendored.ads"
            spec.write_text("   --  Sentence one.  Sentence two.\n"
                            "   X : Integer := 1;\n", encoding="utf-8")
            errors = check_docs.source_spacing_errors(
                spec.relative_to(check_docs.ROOT),
                spec.read_text(encoding="utf-8").splitlines())
            self.assertEqual(len(errors), 1)
            with contextlib.redirect_stdout(io.StringIO()):
                check_docs.fix()
            self.assertEqual(
                spec.read_text(encoding="utf-8"),
                "   --  Sentence one. Sentence two.\n   X : Integer := 1;\n")

    def test_patch_files_out_of_scope_when_directory_missing(self) -> None:
        # A repository without .adacovex/patches reports no patch files (and
        # the gate still passes).
        with tempfile.TemporaryDirectory() as tmp:
            check_docs.ROOT = Path(tmp)
            self.assertEqual(check_docs.patch_files(), [])

class TestCheckDocsCoverage(unittest.TestCase):
    """The documentation-coverage gate (tools/check-docs-coverage.py).

    The gate turns the manual CLI-reference / dashboard audit into a check:
    every CLI flag, every server route, and every hand-written usage or
    contributing page must be covered by the user documentation.
    """

    def test_flag_documented_accepts_both_spellings(self) -> None:
        docs = "Use `--target=PATH`. Run `status` for the toolkit."
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
                         "/api/info", "/health",
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

class TestCheckSurfaceParity(unittest.TestCase):
    """The CLI-surface parity gate (tools/check-surface-parity.py).

    The gate pins the --help / man / cli-reference / completion surfaces to
    the parser's subcommand set and the tldr prose to the README tagline.
    """

    def test_subcommands_are_the_parser_bare_words(self) -> None:
        # The gate reads the parser's `elsif A = "word" then` branches, so
        # its set is only as good as that source.  Pin the expected ten.
        self.assertEqual(
            check_surface_parity.subcommands(),
            {"sbom", "prove", "complexity", "spark-coverage", "status",
             "completion", "man", "tldr", "init", "help"})

    def test_the_tagline_comes_from_the_readme(self) -> None:
        tagline = check_surface_parity.readme_tagline()
        # The article is stripped and the case is folded, so a surface may
        # capitalise freely while the substance must still match.
        self.assertTrue(tagline.startswith("zero-dependency ada/spark"),
                        tagline)
        self.assertIn("interactive dashboards", tagline)
        self.assertEqual(tagline, tagline.casefold())

    def test_reference_surfaces_advertise_every_subcommand(self) -> None:
        subs = check_surface_parity.subcommands()
        for name, text in (
            ("help", check_surface_parity._usage_block(
                check_surface_parity._config_text())),
            ("man", check_surface_parity.man_synopsis()),
            ("cli-reference", check_surface_parity.cli_reference_fence()),
        ):
            self.assertEqual(
                subs,
                check_surface_parity._advertised_subcommands(text),
                f"{name} surface drift")

    def test_completion_scripts_offer_every_subcommand(self) -> None:
        subs = check_surface_parity.subcommands()
        for shell, shell_subs in check_surface_parity.completion_subsets().items():
            self.assertEqual(subs, shell_subs, f"{shell} completion drift")

    def test_the_current_tree_passes_the_gate(self) -> None:
        # The real tree is the fixture: every surface agrees.
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check_surface_parity.check(), 0)

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
        # The link check runs against a fresh build (docs/_build/html is a
        # local, gitignored product): a stale local build must never mask a
        # broken link.  Requires sphinx-build, exactly like the gate itself.
        #
        # `just check` builds the manual twice -- once for the
        # book-links-check gate and once here -- and a full Sphinx build was
        # the most expensive thing in the gate list (measured 17.6-31.8 s for
        # the gate and 18.57 s for this case).  Both now go through
        # check_book_links.fresh_book(), whose cache is keyed by the docs
        # content digest plus the Sphinx build identity, so the first caller
        # builds and the second reuses.  A changed docs/ tree still rebuilds,
        # which is the property that keeps a stale build from masking a
        # broken link.
        if gen_docs.sphinx_build_cmd() is None:
            self.skipTest("sphinx-build not resolvable (PATH or .venv)")
        out = check_book_links.fresh_book()
        self.assertIsNotNone(out, "a fresh manual build is available")
        assert out is not None
        self.assertTrue((out / "index.html").is_file())
        self.assertTrue((out / "searchindex.js").is_file())
        # The fresh build carries the same self-contained link surface.
        assets = gen_docs.collect_assets(out)
        self.assertEqual(check_book_links.check_bundle_links(assets), [])

    def test_fresh_build_is_cached_by_content(self) -> None:
        # The shared build must be keyed by the docs content, so a second
        # call reuses it and a changed tree does not.
        if gen_docs.sphinx_build_cmd() is None:
            self.skipTest("sphinx-build not resolvable (PATH or .venv)")
        key = check_book_links.book_build_key()
        self.assertIsNotNone(key)
        assert key is not None
        self.assertEqual(key, check_book_links.book_build_key(),
                         "the build key is stable for an unchanged tree")
        # The key carries the sphinx-build path, so it is sanitised where it
        # becomes a directory name; the sanitised name must stay one level.
        safe = re.sub(r"[^A-Za-z0-9._-]", "_", key)
        self.assertNotIn("/", safe, "the cache entry name is one level")
        self.assertNotIn(os.sep, safe, "the cache entry name has no separator")

    def test_cached_build_survives_a_docs_change(self) -> None:
        # A docs/ edit must change the key, so the cached build is never
        # served for content it was not built from.
        if gen_docs.sphinx_build_cmd() is None:
            self.skipTest("sphinx-build not resolvable (PATH or .venv)")
        before = check_book_links.book_build_key()
        marker = check_book_links.ROOT / "docs" / "_book_key_probe.md"
        try:
            marker.write_text("cache key probe\n", encoding="utf-8")
            after = check_book_links.book_build_key()
        finally:
            marker.unlink(missing_ok=True)
        self.assertNotEqual(before, after,
                            "a new docs page changes the build key")

class TerminologyTests(unittest.TestCase):
    """adacovex calls its own tool set a toolkit; external tool sets stay
    toolchains."""

    ROOTS: tuple = (
        "src", "docs/usage", "docs/contributing", "docs/changelogs",
        "docs/index.md", "README.md", "AGENTS.md", "CONTRIBUTING.md",
        "action.yml", "install.sh", "alire.toml", "alire-dev.toml",
        "alire/long-description.txt", ".github",
    )
    SUFFIXES: tuple = (
        ".ads", ".adb", ".md", ".py", ".yml", ".yaml", ".toml", ".txt",
        ".sh",
    )
    #  Every phrase here names a part of adacovex's own product, cache, or
    #  bundle. An external tool set keeps the word toolchain.
    FORBIDDEN: tuple = (
        "adacovex toolchain", "covex toolchain", "our toolchain",
        "toolchain cache", "toolchain resolution", "Toolchain_Dir",
        "Toolchain_Cache", "ADACOVEX_TOOLCHAIN_URL", "<data>/toolchain",
        "adacovex-toolchain-",
    )
    #  The external proof tool set keeps its own name, including the
    #  architecture heading and the host-side cache notes.
    EXTERNAL: tuple = (
        "gnatprove toolchain resolution", "host-side toolchain caches",
        "toolchain caches",
    )

    def test_adacovex_never_calls_its_own_tool_set_a_toolchain(self) -> None:
        root = Path(__file__).resolve().parent.parent
        offenders: list = []
        for entry in self.ROOTS:
            base = root / entry
            paths = [base] if base.is_file() else base.rglob("*")
            for path in paths:
                if not path.is_file() or path.suffix not in self.SUFFIXES:
                    continue
                if {"obj", ".venv", "node_modules", "_build"} & set(
                        path.relative_to(root).parts):
                    continue
                for number, line in enumerate(
                        path.read_text(encoding="utf-8", errors="replace")
                        .splitlines(), 1):
                    lower = line.lower()
                    if any(phrase in lower for phrase in self.EXTERNAL):
                        continue
                    #  A migration note contrasts the retired name with the
                    #  new one on purpose, so both words appear together.
                    if "toolchain" in lower and "toolkit" in lower:
                        continue
                    if "renamed this directory" in lower:
                        continue
                    for phrase in self.FORBIDDEN:
                        if phrase.lower() in lower:
                            offenders.append(
                                f"{path.relative_to(root)}:{number}: "
                                f"{line.strip()}")
                            break
        self.assertEqual(offenders, [], "\n".join(offenders))

    def test_the_style_guide_names_both_terms(self) -> None:
        root = Path(__file__).resolve().parent.parent
        text = (root / "docs/contributing/ste100/tooling-terms.md").read_text(
            encoding="utf-8")
        self.assertIn("## Technical Name: Toolchain", text)
        self.assertIn("## Technical Name: Toolkit", text)

class DocsTreeTests(unittest.TestCase):
    """The AGENTS.md docs tree is generated from the pages' headings."""

    def test_title_reads_a_heading_after_badges(self) -> None:
        root = Path(__file__).resolve().parent.parent
        self.assertEqual(gen_docs_tree.title_of(root / "README.md"),
                         "adacovex")

    def test_render_lists_usage_and_generated_trees(self) -> None:
        files, untitled = gen_docs_tree.collect()
        self.assertEqual(untitled, [])
        text = "\n".join(gen_docs_tree.render(files))
        self.assertIn("|-- usage/", text)
        self.assertIn("api-docs/ (generated by", text)
        self.assertIn("cli-reference.md -- adacovex CLI Reference", text)
