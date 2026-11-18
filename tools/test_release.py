"""Release, version, and description-sync tests."""

from testsupport import *  # noqa: F401,F403


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

    def test_current_branch_reads_the_checked_out_branch(self) -> None:
        make_git_repo(self._root, [])
        self.assertEqual(release.current_branch(), "main")
        git(self._root, "checkout", "-q", "-b", "feature")
        self.assertEqual(release.current_branch(), "feature")

    def test_main_refuses_a_non_main_branch(self) -> None:
        # A release from a feature branch would tag that branch and start
        # the same publish, so the guard must stop before anything runs.
        make_git_repo(self._root, [])
        git(self._root, "checkout", "-q", "-b", "feature")
        err = io.StringIO()
        with mock.patch.object(release, "release") as rel, \
                mock.patch.object(sys, "argv", ["release.py"]), \
                contextlib.redirect_stderr(err):
            self.assertEqual(release.main(), 1)
        rel.assert_not_called()
        self.assertIn("main branch only", err.getvalue())

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
        #  Windows refuses a symlink without elevation, so the bundler falls
        #  back to a byte-for-byte copy: either form must be there, and both
        #  must carry the binary's bytes.
        alias = dist / "covex"
        self.assertTrue(alias.is_file())
        self.assertEqual(alias.read_bytes(), (dist / "adacovex").read_bytes())
        self.assertTrue((dist / "install.sh").is_file())
        self.assertTrue((dist / "THIRD_PARTY_NOTICES.md").is_file())
        with tarfile.open(self._root / "adacovex-v1.2.3.tar.gz", "r:gz") as tar:
            names = tar.getnames()
            self.assertTrue(any(n.endswith("adacovex") for n in names))
            self.assertTrue(any(n.endswith("install.sh") for n in names))
        with tarfile.open(self._root / "adacovex-action-v1.2.3.tar.gz",
                          "r:gz") as tar:
            self.assertIn("action.yml", tar.getnames())

    def _fake_binary(self, version: str, rc: int = 0) -> None:
        """Write a bin/adacovex stub that reports `version` like the real one."""
        write_fake_binary(self._root / "bin" / "adacovex",
                          f"adacovex v{version}", rc)

    def test_verify_binary_version_match(self) -> None:
        self._fake_binary("1.2.3")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertTrue(release.verify_binary_version("1.2.3"))

    def test_verify_binary_version_rejects_stale_binary(self) -> None:
        # The release-ordering regression: the binary under test still
        # reports the previous release's version.
        self._fake_binary("1.2.2")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertFalse(release.verify_binary_version("1.2.3"))
        self.assertIn("v1.2.2", err.getvalue())

    def test_verify_binary_version_rejects_failed_probe(self) -> None:
        self._fake_binary("1.2.3", rc=2)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertFalse(release.verify_binary_version("1.2.3"))

    def test_build_release_binary_forces_the_tag_version(self) -> None:
        # The release must build through tools/build.py --release with
        # ADACOVEX_VERSION set, so the regeneration steps (CSS gate,
        # dashboard, bundled manual) run exactly as they do for a dev build.
        tools_dir = self._root / "tools"
        (tools_dir / "build.py").write_text("", encoding="utf-8")
        seen: dict = {}

        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            seen["cmd"] = cmd
            seen["env"] = kwargs.get("env", {})
            return subprocess.CompletedProcess(cmd, 0)

        with mock.patch.object(release, "sh", fake_sh):
            self.assertEqual(release.build_release_binary("1.2.3"), 0)
        self.assertIn("tools/build.py", seen["cmd"])
        self.assertIn("--release", seen["cmd"])
        self.assertEqual(seen["env"]["ADACOVEX_VERSION"], "1.2.3")

    def test_release_builds_before_proving(self) -> None:
        # just release proved the tree before it built the release binary,
        # so the proof pass ran the previous release's binary.  Pin the
        # order: build, verify, then prove.
        order: List[str] = []

        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            joined = " ".join(cmd)
            for step in ("tools/build.py", "--version", "prove", "coverage-delta"):
                if step in joined:
                    order.append(step)
                    break
            return subprocess.CompletedProcess(
                cmd, 0, stdout="adacovex v1.2.3\n")

        with mock.patch.object(release, "sh", fake_sh), \
                mock.patch.object(release, "previous_tag", return_value=None), \
                mock.patch.object(release, "changelogs_for", return_value=[]), \
                mock.patch.object(release, "bundle"), \
                mock.patch.object(release, "attest"), \
                mock.patch.object(release, "bump_manifests"), \
                mock.patch.object(release, "git_tag_ops"):
            self.assertEqual(release.release("1.2.3", "", "o/r", True), 0)
        self.assertLess(order.index("tools/build.py"), order.index("--version"))
        self.assertLess(order.index("--version"), order.index("prove"))

class ReleaseTagTests(unittest.TestCase):
    """The tag step of `just release`, which is where a late failure lands.

    The commit and tag step runs last, so a failure anywhere before it leaves
    the previous attempt's tag behind.  Re-running therefore has to be
    idempotent, and it used not to be: the replace path asked only the LOCAL
    tag whether origin had one, so a tag this clone had never seen was
    invisible, the delete was skipped, and the following push was refused with
    `! [remote rejected]` and a bare traceback.
    """

    @staticmethod
    def _sh(local: Optional[str], remote: Optional[str],
            push_rc: int = 0, push_stderr: str = "", tag: str = "v1.2.3"):
        """A fake `sh` over a fixed local/remote tag state.

        Returns the list of git subcommands it saw, so a test can assert the
        ORDER of the delete and the push, not just that both happened.
        `landed` models origin's state *after* a successful push, so the
        post-push verification sees what a real origin would report.
        """
        seen: List[str] = []

        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            joined = " ".join(cmd)
            seen.append(joined)
            if "ls-remote" in joined:
                # Before the push origin has `remote`; after it, the new tag.
                if any(c.startswith("git push origin") and ":refs/tags" not in c
                       for c in seen):
                    sha = "newsha"
                else:
                    sha = remote
                if sha is None:
                    return subprocess.CompletedProcess(cmd, 0, stdout="")
                # Model the real ref filter: ls-remote returns the annotated
                # tag OBJECT for an exact ref, and only the trailing `*`
                # pattern also brings back the peeled `^{}` commit line.
                # A fake that always returned both lines hid a real bug --
                # release.py compared a tag object against a commit SHA and
                # failed a push that had landed.
                if cmd[-1].endswith("*"):
                    out = (f"{sha}obj\trefs/tags/{tag}\n"
                           f"{sha}\trefs/tags/{tag}^{{}}\n")
                else:
                    out = f"{sha}obj\trefs/tags/{tag}\n"
                return subprocess.CompletedProcess(cmd, 0, stdout=out)
            if "rev-parse" in joined and "--verify" in joined:
                return subprocess.CompletedProcess(
                    cmd, 0 if local else 1,
                    stdout=(local or "") + "\n")
            if joined.startswith("git push"):
                return subprocess.CompletedProcess(
                    cmd, push_rc, stdout="", stderr=push_stderr)
            if "rev-parse" in joined and "HEAD" in joined:
                return subprocess.CompletedProcess(cmd, 0, stdout="newsha\n")
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

        return fake_sh, seen

    def test_remote_tag_absent_returns_none(self) -> None:
        fake, _ = self._sh(local=None, remote=None)
        with mock.patch.object(release, "sh", fake):
            self.assertIsNone(release.remote_tag_sha("v1.2.3"))

    def test_remote_tag_prefers_the_peeled_commit(self) -> None:
        # An annotated tag has a tag object and a commit; only the commit is
        # comparable with a local `rev-parse tag^{}`.
        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            if "ls-remote" in " ".join(cmd):
                out = ("tagobj\trefs/tags/v1.2.3\n"
                       "commit\trefs/tags/v1.2.3^{}\n")
                return subprocess.CompletedProcess(cmd, 0, stdout=out)
            return subprocess.CompletedProcess(cmd, 0, stdout="")

        with mock.patch.object(release, "sh", fake_sh):
            self.assertEqual(release.remote_tag_sha("v1.2.3"), "commit")

    def test_ls_remote_pattern_keeps_the_peeled_line(self) -> None:
        # The ref pattern must carry a trailing `*`.  Naming the exact ref
        # makes ls-remote return the tag object and drop the `^{}` commit
        # line, so the comparison is against the wrong identity and a good
        # push reads as a mismatch.
        seen: List[str] = []

        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            seen.append(cmd[-1])
            return subprocess.CompletedProcess(cmd, 0, stdout="")

        with mock.patch.object(release, "sh", fake_sh):
            release.remote_tag_sha("v1.2.3")
        self.assertEqual(seen, ["refs/tags/v1.2.3*"])

    def test_unreachable_origin_stops_the_release(self) -> None:
        # "Cannot ask origin" must never be read as "origin has no tag": that
        # is the confusion that produced the rejected push.
        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            if "ls-remote" in " ".join(cmd):
                return subprocess.CompletedProcess(
                    cmd, 128, stdout="", stderr="fatal: could not read")
            return subprocess.CompletedProcess(cmd, 0, stdout="")

        with mock.patch.object(release, "sh", fake_sh), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                release.git_tag_ops("1.2.3", dry_run=False)
        self.assertIn("cannot ask origin", str(ctx.exception))

    def test_remote_only_tag_is_replaced_before_pushing(self) -> None:
        # The regression: origin has the tag, this clone does not.  The delete
        # must happen even though there is no local tag to find.
        fake, seen = self._sh(local=None, remote="oldsha")
        with mock.patch.object(release, "sh", fake), \
                contextlib.redirect_stdout(io.StringIO()):
            release.git_tag_ops("1.2.3", dry_run=False)
        joined = "\n".join(seen)
        self.assertIn(":refs/tags/v1.2.3", joined)
        self.assertLess(joined.index(":refs/tags/v1.2.3"),
                        joined.index("git push origin v1.2.3"))

    def test_push_refusal_is_reported_not_raised(self) -> None:
        # A refusal must read as a sentence with the remedy, not a traceback.
        fake, _ = self._sh(local=None, remote=None, push_rc=1,
                           push_stderr="! [remote rejected] v1.2.3 -> v1.2.3")
        with mock.patch.object(release, "sh", fake), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                release.git_tag_ops("1.2.3", dry_run=False)
        message = str(ctx.exception)
        self.assertIn("remote rejected", message)
        self.assertIn("Protected tags", message)

    def test_verifies_the_tag_landed(self) -> None:
        # A push that reports success but lands nothing is the failure a
        # release cannot discover later, so the result is re-read from origin.
        def fake_sh(cmd: List[str], check: bool = True, **kwargs) -> object:
            joined = " ".join(cmd)
            if "ls-remote" in joined:
                return subprocess.CompletedProcess(cmd, 0, stdout="")
            if "rev-parse" in joined and "HEAD" in joined:
                return subprocess.CompletedProcess(cmd, 0, stdout="newsha\n")
            if "rev-parse" in joined and "--verify" in joined:
                return subprocess.CompletedProcess(cmd, 1, stdout="")
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

        with mock.patch.object(release, "sh", fake_sh), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                release.git_tag_ops("1.2.3", dry_run=False)
        self.assertIn("does not carry", str(ctx.exception))

    def test_dry_run_reports_tag_state_and_writes_nothing(self) -> None:
        fake, seen = self._sh(local="localsha", remote="remotesha")
        buf = io.StringIO()
        with mock.patch.object(release, "sh", fake), \
                contextlib.redirect_stdout(buf):
            release.git_tag_ops("1.2.3", dry_run=True)
        out = buf.getvalue()
        self.assertIn("localsha", out)
        self.assertIn("remotesha", out)
        self.assertIn("would replace", out)
        for command in seen:
            self.assertNotIn("commit", command)
            self.assertNotIn("tag -a", command)

    def test_dry_run_on_a_clean_tree_says_so(self) -> None:
        fake, _ = self._sh(local=None, remote=None)
        buf = io.StringIO()
        with mock.patch.object(release, "sh", fake), \
                contextlib.redirect_stdout(buf):
            release.git_tag_ops("1.2.3", dry_run=True)
        out = buf.getvalue()
        self.assertIn("no such tag", out)
        self.assertNotIn("would replace", out)

class SyncToolCheckModeTests(unittest.TestCase):
    """`--check` must never write.

    These tools are invoked as `just check` gates in check mode, where they
    are expected to *report* drift rather than repair it.  A tool that quietly
    started writing in check mode would turn a gate into a silent repair: the
    run goes green, the tree moves, and the commit ends up holding an artefact
    nobody reviewed.  So each one is run against the real tree with a git
    status snapshot taken either side, and any write fails the test.
    """

    TOOLS: Tuple[Tuple[str, ...], ...] = (
        ("tools", "update-proof-status.py"),
        ("tools", "update-test-count.py"),
        ("tools", "update-description.py"),
    )

    @staticmethod
    def _root() -> Path:
        return Path(__file__).resolve().parent.parent

    @classmethod
    def _status(cls) -> str:
        result = subprocess.run(
            ["git", "status", "--porcelain"], cwd=str(cls._root()),
            capture_output=True, text=True)
        return result.stdout

    @classmethod
    def _run_checked(cls, tool: Tuple[str, ...]) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(cls._root().joinpath(*tool)), "--check"],
            cwd=str(cls._root()), capture_output=True, text=True)

    def test_check_mode_writes_nothing(self) -> None:
        # One tool per failure, so the message names the culprit.
        for tool in self.TOOLS:
            with self.subTest(tool=tool[-1]):
                before = self._status()
                result = self._run_checked(tool)
                after = self._status()
                self.assertEqual(
                    before, after,
                    f"{tool[-1]} --check modified the working tree")
                # A clean tree must also pass, or the gate is meaningless.
                self.assertEqual(
                    result.returncode, 0,
                    f"{tool[-1]} --check failed on an up-to-date tree: "
                    f"{result.stdout}{result.stderr}")

    def test_check_flag_is_documented(self) -> None:
        # The gate recipes depend on the exact spelling, so a rename must fail
        # here rather than at release time.
        for tool in self.TOOLS:
            with self.subTest(tool=tool[-1]):
                text = self._root().joinpath(*tool).read_text(encoding="utf-8")
                self.assertIn('add_argument("--check"', text)
                self.assertIn("--check", text.split('"""')[1])

class TestVersionConsistency(unittest.TestCase):
    """Every version source must name the same version."""

    def setUp(self) -> None:
        self._orig_root = check_version.ROOT
        self._orig = (check_version.MANIFESTS, check_version.VERSION_SPEC,
                      check_version.BINARY, check_version.SBOM)
        self._tmp = tempfile.TemporaryDirectory()
        self._root = Path(self._tmp.name)
        check_version.ROOT = self._root
        (self._root / "src").mkdir()
        (self._root / "bin").mkdir()
        check_version.MANIFESTS = (self._root / "alire.toml",
                                   self._root / "alire-dev.toml")
        check_version.VERSION_SPEC = self._root / "src" / "adacovex_version_info.ads"
        check_version.BINARY = self._root / "bin" / "adacovex"
        check_version.SBOM = self._root / "sbom.json"

    def tearDown(self) -> None:
        check_version.ROOT = self._orig_root
        (check_version.MANIFESTS, check_version.VERSION_SPEC,
         check_version.BINARY, check_version.SBOM) = self._orig
        self._tmp.cleanup()

    def _write(self, version: str, dev: str = None, spec: str = None,
               sbom_tool: str = None, sbom_root: str = None) -> None:
        """Write a consistent tree, then override the parts under test."""
        dev = dev or version
        spec = spec or version
        sbom_tool = sbom_tool or version
        sbom_root = sbom_root or version
        (self._root / "alire.toml").write_text(f'version = "{version}"\n',
                                              encoding="utf-8")
        (self._root / "alire-dev.toml").write_text(f'version = "{dev}"\n',
                                                   encoding="utf-8")
        (self._root / "src" / "adacovex_version_info.ads").write_text(
            f'   Version : constant String := "{spec}";\n', encoding="utf-8")
        (self._root / "sbom.json").write_text(
            '{"name": "adacovex", "version": "%s"}, '
            '"purl": "pkg:alire/covex@%s"\n' % (sbom_tool, sbom_root),
            encoding="utf-8")

    def test_consistent_tree_passes(self) -> None:
        self._write("1.2.3")
        self.assertEqual(check_version.check("1.2.3"), [])

    def test_unbuilt_binary_is_skipped(self) -> None:
        # The gate must be meaningful in a fresh checkout before `just build`.
        self._write("1.2.3")
        self.assertIsNone(check_version.binary_version())
        self.assertEqual(check_version.check("1.2.3"), [])

    def test_dev_manifest_drift(self) -> None:
        self._write("1.2.3", dev="1.2.2")
        problems = check_version.check("1.2.3")
        self.assertTrue(any("alire-dev.toml" in p for p in problems))

    def test_stale_version_spec(self) -> None:
        self._write("1.2.3", spec="1.2.2")
        problems = check_version.check("1.2.3")
        self.assertTrue(any("gen-version.py" in p for p in problems))

    def test_stale_binary(self) -> None:
        self._write("1.2.3")
        write_fake_binary(self._root / "bin" / "adacovex", "adacovex v1.2.2")
        problems = check_version.check("1.2.3")
        self.assertTrue(any("is stale" in p for p in problems))

    def test_sbom_tool_version_behind_release(self) -> None:
        # The exact defect the committed 1.54.0 tree carried.
        self._write("1.2.3", sbom_tool="1.2.2")
        problems = check_version.check("1.2.3")
        self.assertTrue(any("just sbom" in p for p in problems))

    def test_sbom_internal_disagreement(self) -> None:
        self._write("1.2.3", sbom_root="1.2.2")
        problems = check_version.check("1.2.3")
        self.assertTrue(any("root component" in p for p in problems))

    def test_readers(self) -> None:
        self._write("1.2.3")
        self.assertEqual(check_version.manifest_version(self._root / "alire.toml"),
                         "1.2.3")
        self.assertEqual(check_version.spec_version(), "1.2.3")
        self.assertEqual(check_version.sbom_versions(), ("1.2.3", "1.2.3"))

    def test_manifest_split_accepts_the_published_shape(self) -> None:
        publishing = 'name = "covex"\nversion = "1.2.3"\n'
        dev = ('name = "covex"\nversion = "1.2.3"\n[[depends-on]]\n'
               'gnatprove = "^16.1.0"\n')
        self.assertEqual(
            check_version.manifest_split_problems(publishing, dev), [])

    def test_manifest_split_rejects_a_dev_dependency(self) -> None:
        # The residue of an interrupted tools/dev-cmd.py swap.
        publishing = ('name = "covex"\nversion = "1.2.3"\n[[depends-on]]\n'
                      'gnatprove = "^16.1.0"\n')
        problems = check_version.manifest_split_problems(publishing,
                                                        publishing + "\n")
        self.assertTrue(any("gnatprove" in p for p in problems))
        self.assertTrue(any("zero-dependency" in p for p in problems))

    def test_manifest_split_rejects_an_identical_pair(self) -> None:
        same = 'name = "covex"\nversion = "1.2.3"\n'
        problems = check_version.manifest_split_problems(same, same)
        self.assertTrue(any("identical" in p for p in problems))

    def test_manifest_split_requires_the_dev_pin(self) -> None:
        publishing = 'name = "covex"\nversion = "1.2.3"\n'
        dev = 'name = "covex"\nversion = "1.2.3"\n[[depends-on]]\n'
        problems = check_version.manifest_split_problems(publishing, dev)
        self.assertTrue(any("does not pin gnatprove" in p for p in problems))

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

class RequirementsSyncTests(unittest.TestCase):
    """pyproject.toml single-sources the docs deps (update-requirements).

    requirements.txt stays committed for .readthedocs.yaml and `pip install
    -r`, so it is derived: these tests pin the render, the drift detection,
    and the gate/task wiring that keeps the derived file honest with the
    single source, plus the install.sh python-venv mode that is the middle
    step of the documented venv bootstrap order.
    """

    def _toml_str(self, value: str) -> str:
        """TOML-encode one dependency string for the probe pyproject."""
        if '"' in value:
            return "'" + value + "'"
        return '"' + value + '"'

    def _write_pyproject(self, directory: Path, deps: List[str]) -> Path:
        entries = "\n".join("    " + self._toml_str(d) + "," for d in deps)
        path = directory / "pyproject.toml"
        path.write_text(
            '[project]\nname = "adacovex-probe"\nversion = "0.0.0"\n'
            f"dependencies = [\n{entries}\n]\n",
            encoding="utf-8")
        return path

    def test_render_is_marked_generated_and_keeps_order(self) -> None:
        deps = ["sphinx", "myst-parser", "furo"]
        out = update_reqs.render_requirements(deps)
        self.assertIn("GENERATED FILE", out)
        self.assertIn("pyproject.toml", out)
        self.assertTrue(out.endswith("\n"))
        lines = [ln for ln in out.splitlines()
                 if ln and not ln.startswith("#")]
        self.assertEqual(lines, deps, "dependency order must follow the table")

    def test_load_dependencies_passes_pins_and_markers_through(self) -> None:
        deps = ['sphinx>=7', 'furo; python_version < "3.13"', 'myst-parser[linkify]']
        with tempfile.TemporaryDirectory() as tmp:
            py = self._write_pyproject(Path(tmp), deps)
            self.assertEqual(update_reqs.load_dependencies(py), deps)

    def test_missing_or_empty_table_fails_loudly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            py = Path(tmp) / "pyproject.toml"
            py.write_text('[project]\nname = "x"\n', encoding="utf-8")
            with self.assertRaises(SystemExit):
                update_reqs.load_dependencies(py)

    def test_check_flags_drift_and_a_write_repairs_it(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            py = self._write_pyproject(d, ["sphinx", "furo"])
            req = d / "requirements.txt"
            req.write_text("sphinx\n", encoding="utf-8")  # stale: furo missing
            with contextlib.redirect_stdout(io.StringIO()), \
                    contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(
                    update_reqs.sync(py, req, check_only=True), 1,
                    "--check must fail on drift")
                self.assertEqual(update_reqs.sync(py, req, check_only=False), 0)
                self.assertEqual(
                    update_reqs.sync(py, req, check_only=True), 0,
                    "a rewrite must satisfy --check")
            self.assertEqual(req.read_text(encoding="utf-8"),
                             update_reqs.render_requirements(["sphinx", "furo"]))

    def test_in_sync_file_is_not_rewritten(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            py = self._write_pyproject(d, ["sphinx"])
            req = d / "requirements.txt"
            expected = update_reqs.render_requirements(["sphinx"])
            req.write_text(expected, encoding="utf-8")
            stat_before = req.stat().st_mtime_ns
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(update_reqs.sync(py, req, check_only=False), 0)
            self.assertEqual(req.stat().st_mtime_ns, stat_before,
                             "a no-op run must keep the file's mtime")

    def test_requirement_gate_and_task_are_registered(self) -> None:
        gates = tasks.check_gate_labels()
        self.assertIn("requirements sync", gates,
                      "the sync gate must run inside `just check`")
        self.assertIn("requirements", tasks.TASKS,
                      "`just requirements` must reach the generator")

    def test_justfile_bootstraps_in_the_documented_order(self) -> None:
        # uv first, else the project's install.sh, else python3 -m venv:
        # the documented bootstrap order lives in the docs-venv recipe.
        text = (Path(__file__).resolve().parent.parent /
                "justfile").read_text(encoding="utf-8")
        i_uv = text.index("command -v uv")
        i_sh = text.index("install.sh --python-venv .venv")
        i_venv = text.index('"$PYEXE" -m venv .venv')
        self.assertLess(i_uv, i_sh)
        self.assertLess(i_sh, i_venv, "the venv fallback must come last")

    def test_install_sh_offers_the_python_venv_mode(self) -> None:
        text = (Path(__file__).resolve().parent.parent /
                "install.sh").read_text(encoding="utf-8")
        self.assertIn('"--python-venv"', text)
        self.assertIn("-m venv", text)
        self.assertIn("requirements.txt", text)
        # The mode must exit before any release download starts.
        self.assertLess(text.index('"--python-venv"'),
                        text.index("curl -fsSL \"$URL\""),
                        "the venv mode must not reach the download path")
