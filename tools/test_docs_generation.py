"""API-doc, dashboard, tldr, and bundled-manual generator tests."""

from testsupport import *  # noqa: F401,F403


class TestRst2Md(unittest.TestCase):
    """rst2md sanitisation keeps generated api-docs pure ASCII."""

    def test_mojibake_em_dash_maps_to_colon(self) -> None:
        self.assertEqual(rst2md.fix_text("a\u00e2\u0080\u0094b"), "a:b")

    def test_unicode_ellipsis_maps_to_dots(self) -> None:
        # gnatdoc abbreviates long enum declarations with U+2026.
        self.assertEqual(rst2md.fix_text("a\u2026b"), "a...b")

    def test_plain_ascii_passes_through(self) -> None:
        self.assertEqual(rst2md.fix_text("type Route_Kind is"), "type Route_Kind is")

    def test_type_body_does_not_hide_later_subprograms(self) -> None:
        #  A multi-line enumeration has no `end record`, so its opening
        #  `type X is` line must not leave the record counter raised.
        with tempfile.TemporaryDirectory() as tmp:
            spec = Path(tmp, "adacovex-probe.ads")
            spec.write_text(
                "package Adacovex_Probe is\n"
                "\n"
                "   type Level is\n"
                "     (Stone,\n"
                "      Gold);\n"
                "\n"
                "   --  Return the level name.\n"
                "   --  @param L  Level to name.\n"
                "   --  @return Level name.\n"
                "   function Name_Of (L : Level) return String;\n"
                "\n"
                "end Adacovex_Probe;\n",
                encoding="utf-8", newline="\n")
            _, annotations, _, _ = rst2md.parse_ada_annotations(str(spec))
            self.assertIn("Name_Of:L", annotations)
            self.assertEqual(annotations["Name_Of:L"]["params"]["L"],
                             "Level to name.")

    def test_docstring_prose_becomes_the_description(self) -> None:
        #  gnatdoc leaves the item description out of its RST directives,
        #  so the prose of the .ads docstring supplies it.
        with tempfile.TemporaryDirectory() as tmp:
            spec = Path(tmp, "adacovex-probe.ads")
            spec.write_text(
                "package Adacovex_Probe is\n"
                "\n"
                "   --  Scan one file. The scan is read-only.\n"
                "   --  HLR-SCAN: scanning\n"
                "   --  @param File_Path  Path to the file.\n"
                "   --  @return True when the scan succeeded.\n"
                "   function Scan (File_Path : String) return Boolean;\n"
                "\n"
                "end Adacovex_Probe;\n",
                encoding="utf-8", newline="\n")
            _, annotations, _, _ = rst2md.parse_ada_annotations(str(spec))
            self.assertEqual(annotations["Scan:File_Path"]["desc"],
                             "Scan one file. The scan is read-only.")

    def test_wrapped_annotation_stays_with_its_parameter(self) -> None:
        #  An @param description may wrap onto the next comment line. The
        #  continuation belongs to the parameter, never to the description.
        with tempfile.TemporaryDirectory() as tmp:
            spec = Path(tmp, "adacovex-probe.ads")
            spec.write_text(
                "package Adacovex_Probe is\n"
                "\n"
                "   --  Run the prover.\n"
                "   --  @param Pin  Version pin (\"\" = none. The\n"
                "   --  manifest pin is still preferred).\n"
                "   procedure Run (Pin : String);\n"
                "\n"
                "end Adacovex_Probe;\n",
                encoding="utf-8", newline="\n")
            _, annotations, _, _ = rst2md.parse_ada_annotations(str(spec))
            self.assertEqual(annotations["Run:Pin"]["desc"], "Run the prover.")
            self.assertEqual(annotations["Run:Pin"]["params"]["Pin"],
                             'Version pin ("" = none. The manifest pin is '
                             'still preferred).')

    def test_enumeration_comment_on_last_alternative_closes_the_body(
            self) -> None:
        #  The last alternative of a multi-line enumeration may carry a
        #  trailing comment; the type still ends at its `;`, so the type
        #  block must not swallow the subprogram that follows it.
        with tempfile.TemporaryDirectory() as tmp:
            spec = Path(tmp, "adacovex-probe.ads")
            spec.write_text(
                "package Adacovex_Probe is\n"
                "\n"
                "   type Status is\n"
                "     (Created,  --  the file was written\n"
                "      Failed);  --  the file could not be written\n"
                "\n"
                "   --  Write the file.\n"
                "   --  @param Force  Overwrite an existing file.\n"
                "   procedure Write (Force : Boolean);\n"
                "\n"
                "end Adacovex_Probe;\n",
                encoding="utf-8", newline="\n")
            _, annotations, _, _ = rst2md.parse_ada_annotations(str(spec))
            self.assertIn("Write:Force", annotations)
            self.assertEqual(annotations["Write:Force"]["params"]["Force"],
                             "Overwrite an existing file.")

    def test_incomplete_items_names_each_gap(self) -> None:
        page = (
            "### function Name_Of (L : Level) return String\n"
            "\n"
            "| Parameter | Description |\n"
            "|-----------|-------------|\n"
            "| `L` |  |\n"
            "\n"
            "**Returns:** Level name.\n"
            "\n"
            "### type Level\n"
            "\n"
            "```ada\ntype Level is (Stone, Gold);\n```\n"
        )
        problems = rst2md.incomplete_items(page)
        self.assertEqual(len(problems), 3)
        self.assertIn("function Name_Of (L : Level) return String has no "
                      "description", problems[0])
        self.assertIn("empty parameter description", problems[1])
        self.assertIn("type Level has no description", problems[2])

    def test_complete_item_passes(self) -> None:
        page = (
            "### function Name_Of (L : Level) return String\n"
            "\n"
            "> Name one level.\n"
            "\n"
            "| Parameter | Description |\n"
            "|-----------|-------------|\n"
            "| `L` | Level to name. |\n"
            "\n"
            "**Returns:** Level name.\n"
        )
        self.assertEqual(rst2md.incomplete_items(page), [])

    def test_header_example_tags_do_not_leak(self) -> None:
        #  A docstring example in the file header is prose, not the
        #  annotation block of the first subprogram.
        with tempfile.TemporaryDirectory() as tmp:
            spec = Path(tmp, "adacovex-probe.ads")
            spec.write_text(
                "--  Supported annotations:\n"
                "--    @param Name  Description of a parameter.\n"
                "\n"
                "package Adacovex_Probe is\n"
                "\n"
                "   --  Scan one file.\n"
                "   --  @param File_Path  Path to the file.\n"
                "   --  @param Success  True when the scan succeeded.\n"
                "   procedure Scan (File_Path : String; Success : out Boolean);\n"
                "\n"
                "end Adacovex_Probe;\n",
                encoding="utf-8", newline="\n")
            _, annotations, _, _ = rst2md.parse_ada_annotations(str(spec))
            self.assertIn("Scan:File_Path,Success", annotations)
            self.assertNotIn("Name", annotations["Scan:File_Path,Success"]["params"])

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
        self.assertEqual(len(scripts), 13)

class TestGenTldr(unittest.TestCase):
    """gen-tldr.py bundles the tldr page byte for byte."""

    PAGE: str = "# adacovex\n> One line.\n\n- Run it:\n`adacovex`\n"

    def test_render_is_a_string_constant(self) -> None:
        spec = gen_tldr.render(self.PAGE)
        self.assertIn("package Adacovex.Tldr_Template is", spec)
        self.assertIn("Page : constant String :=", spec)

    def test_render_keeps_every_newline(self) -> None:
        # One ASCII.LF per page newline, so the installed page ends exactly
        # where the authored page ends.
        spec = gen_tldr.render(self.PAGE)
        self.assertEqual(spec.count("ASCII.LF"), self.PAGE.count("\n"))

    def test_render_rejects_an_empty_page(self) -> None:
        with self.assertRaises(ValueError):
            gen_tldr.render("")

    def test_generate_writes_only_on_change(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "adacovex-tldr_template.ads"
            source = Path(td) / "page.md"
            source.write_text(self.PAGE, encoding="ascii")
            self.assertTrue(gen_tldr.generate(out, source))
            self.assertFalse(gen_tldr.generate(out, source))

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

class TestGenDocsSearchIndex(unittest.TestCase):
    """The bundled search index is a pure function of the sources (1.63.0).

    Sphinx merges an incremental index with the one already on disk and
    prunes by emptying a word's document set without dropping the key, so an
    index carrying build history holds phantom entries (`"appveyor":[]`)
    that a clean build never emits -- and `--check` on a cold machine (a
    clean build) failed the committed spec for exactly those phantoms.  The
    generator canonicalises the index on the way into the bundle, so the
    incremental developer tree and the clean build a fresh clone runs agree
    byte for byte.
    """

    def index(self, data: dict) -> str:
        return "Search.setIndex(" + json.dumps(data, sort_keys=True,
                                                separators=(",", ":")) + ")"

    def test_canonicalise_drops_phantom_entries_and_sorts_keys(self) -> None:
        js = ('Search.setIndex({"terms":{"zeta":[1],"appveyor":[],'
              '"alpha":[2,3]},"titleterms":{"wsl":[],"alpha":[1]},'
              '"docnames":["a","b"]})')
        out = gen_docs.canonicalise_search_index(js)
        data = json.loads(out[len("Search.setIndex("):-1])
        self.assertNotIn("appveyor", out, "an emptied word must be dropped")
        self.assertNotIn("wsl", out)
        self.assertEqual(list(data["terms"]), ["alpha", "zeta"],
                         "keys are canonical, not insertion-ordered")
        self.assertEqual(data["terms"]["alpha"], [2, 3],
                         "a word's documents are kept verbatim")
        self.assertEqual(data["docnames"], ["a", "b"],
                         "fields outside terms/titleterms are untouched")

    def test_canonicalise_is_idempotent(self) -> None:
        js = self.index({"terms": {"b": [1], "a": []},
                         "titleterms": {}, "docnames": ["x"]})
        once = gen_docs.canonicalise_search_index(js)
        self.assertEqual(gen_docs.canonicalise_search_index(once), once)
        self.assertEqual(once, self.index({"terms": {"b": [1]},
                                           "titleterms": {},
                                           "docnames": ["x"]}))

    def test_canonicalise_leaves_foreign_text_alone(self) -> None:
        # A stub (a test build writes "{}"), a truncated file, or a Sphinx
        # layout change must never be rewritten into something unreadable.
        for text in ("{}", "Search.setIndex({", 'Search.setIndex([1,2])',
                     "Search.setIndex(1);", "searchtools.js"):
            self.assertEqual(gen_docs.canonicalise_search_index(text), text)

    def test_collect_assets_canonicalises_the_search_index(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp)
            (build / "index.html").write_text("<html></html>",
                                              encoding="utf-8")
            (build / "searchindex.js").write_text(
                'Search.setIndex({"terms":{"gone":[],"here":[0]},'
                '"titleterms":{}})', encoding="utf-8")
            bodies = {rel: body for rel, _, body in
                      gen_docs.collect_assets(build)}
        self.assertNotIn("gone", bodies["searchindex.js"])
        self.assertIn("here", bodies["searchindex.js"])

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

    def test_shared_reveal_script_is_registered_and_bundled(self) -> None:
        # docs/_static/sidebar-reveal.js serves the online manual (Read the
        # Docs) and is bundled into the offline one, so both manuals reveal
        # the open entry in the drawer.  It is registered through
        # html_js_files; without that line Sphinx builds the pages without it
        # and the file is never even referenced.
        conf = (gen_docs.DOCS / "conf.py").read_text(encoding="utf-8")
        self.assertIn('html_js_files = ["sidebar-reveal.js"]', conf)
        self.assertIn('html_static_path = ["_static"]', conf)
        self.assertTrue(gen_docs.SIDEBAR_REVEAL.is_file())
        # The offline bundle copies every _static asset, so the file reaches
        # the manual without a gen-docs.py special case; assert the suffix is
        # bundled at all, since a .js with no MIME entry would be dropped.
        self.assertEqual(gen_docs._MIME[".js"], "application/javascript")

    def test_shared_reveal_script_reveals_only_the_drawer(self) -> None:
        # The same contract as the injector's reveal, and it must hold for the
        # shared script too: the drawer is the only scroll container.  A
        # scrollIntoView or a window scroll would move the page instead.
        script = gen_docs.SIDEBAR_REVEAL.read_text(encoding="utf-8")
        self.assertIn('entry.closest(".sidebar-scroll")', script)
        self.assertIn("box.scrollTop", script)
        self.assertIn('box.style.scrollBehavior = "auto"', script)
        # Sphinx marks the open page; a page no toctree names has no entry,
        # and the script must leave the drawer alone rather than throw.
        self.assertIn("li.current-page > a", script)
        self.assertIn("if (!entry) { return; }", script)
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
        self.root = root
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

    #  The cold-tree path (1.63.0): a spec that already records these inputs
    #  needs no Sphinx build at all -- a fresh clone used to pay a clean
    #  Sphinx build plus a full re-encode (~9 s) to reproduce the very bytes
    #  it was committing.  `--check` keeps building, so the gate still fails
    #  on a stale or hand-edited spec.

    def matching_spec(self, fingerprint: str) -> Path:
        """A spec outside docs/ carrying the given bundle fingerprint."""
        out = self.root / "src" / "adacovex-docs_template.ads"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            "package Adacovex.Docs_Template is\n"
            "   Source_Fingerprint : constant String :=\n"
            f'     "{fingerprint}";\n'
            "end Adacovex.Docs_Template;\n", encoding="ascii")
        return out

    def current_fingerprint(self) -> str:
        return gen_docs.bundle_fingerprint(gen_docs.docs_source_digests())

    def test_generate_keeps_a_spec_that_already_matches(self) -> None:
        out = self.matching_spec(self.current_fingerprint())
        before = out.read_bytes()
        with mock.patch.object(gen_docs, "build_spec",
                               side_effect=AssertionError("must not build")):
            with contextlib.redirect_stdout(io.StringIO()) as log:
                gen_docs.generate(out)
        self.assertEqual(out.read_bytes(), before)
        self.assertIn("Sphinx not run", log.getvalue())

    def test_generate_rebuilds_when_the_fingerprint_is_stale(self) -> None:
        out = self.matching_spec("0" * 64)
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("rebuilt", "stats")) as build:
            with contextlib.redirect_stdout(io.StringIO()):
                gen_docs.generate(out)
        build.assert_called_once_with(None, False)
        self.assertEqual(out.read_text(encoding="ascii"), "rebuilt")

    def test_generate_fresh_forces_a_build_despite_a_matching_spec(self) -> None:
        out = self.matching_spec(self.current_fingerprint())
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("fresh", "stats")) as build:
            with contextlib.redirect_stdout(io.StringIO()):
                gen_docs.generate(out, fresh=True)
        build.assert_called_once_with(None, True)
        self.assertEqual(out.read_text(encoding="ascii"), "fresh")

    def test_check_always_builds_even_when_the_spec_matches(self) -> None:
        out = self.matching_spec(self.current_fingerprint())
        with mock.patch.object(gen_docs, "build_spec",
                               return_value=("rebuilt", "stats")) as build:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(gen_docs.check(out))
        build.assert_called_once_with(None, False)
        self.assertEqual(out.read_text(encoding="ascii").splitlines()[2],
                         f'     "{self.current_fingerprint()}";',
                         "--check never rewrites the committed spec")

    def test_bundle_fingerprint_follows_every_input(self) -> None:
        before = self.current_fingerprint()
        # A docs source change ...
        (self.docs / "index.md").write_text("# changed\n", encoding="utf-8")
        after_docs = self.current_fingerprint()
        self.assertNotEqual(before, after_docs)
        # ... the bundled nav injector ...
        nav = self.root / "book-nav.js"
        nav.write_text("// v1\n", encoding="utf-8")
        with mock.patch.object(gen_docs, "NAV_SCRIPT_SRC", nav):
            after_nav = gen_docs.bundle_fingerprint(
                gen_docs.docs_source_digests())
        nav.write_text("// v2\n", encoding="utf-8")
        with mock.patch.object(gen_docs, "NAV_SCRIPT_SRC", nav):
            after_nav_edit = gen_docs.bundle_fingerprint(
                gen_docs.docs_source_digests())
        self.assertNotEqual(after_nav, after_nav_edit)
        # ... and the generator's own source all move it.
        with mock.patch.object(gen_docs, "generator_bytes",
                               return_value=b"old generator"):
            stale = gen_docs.bundle_fingerprint(
                gen_docs.docs_source_digests())
        self.assertNotEqual(after_nav_edit, stale)
