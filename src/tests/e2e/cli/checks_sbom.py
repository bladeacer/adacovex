"""SBOM, target-equivalence, and Markdown-output checks."""

from cli_support import *  # noqa: F401,F403


def check_sbom_shapes(r: Results, tmp: Path) -> None:
    """Pin the component sets of two real-project dependency shapes.

    The native suite covers each parser in isolation; these checks run
    the whole `sbom` pipeline over miniature copies of the shapes the
    sibling projects have (lccst's pnpm workspace, kibtab/ocd/swag's Go
    module), so a parsing regression fails a gate instead of a manual
    run.  `system` rows are dropped because they track the host PATH.
    """
    pnpm = tmp / "shape-pnpm"
    write_fixture(pnpm, {
        "alire.toml": 'name = "shapepnpm"\nversion = "1.0.0"\n',
        #  The declared set (six packages) plus decoys: a package's own
        #  subpackage manifests and source trees must never register.
        "package.json": (
            '{\n'
            '  "name": "shapepnpm",\n'
            '  "dependencies": {"zod": "^4.4.3", '
            '"@modelcontextprotocol/sdk": "^1.29.0"},\n'
            '  "devDependencies": {"@types/node": "^20.19.43", '
            '"esbuild": "^0.28.1", "tsx": "^4.22.4", '
            '"typescript": "^5.9.3"}\n'
            '}\n'),
        "pnpm-lock.yaml": (
            "lockfileVersion: '9.0'\n\nimporters:\n\n  .:\n"
            "    dependencies:\n"
            "      zod:\n"
            "        specifier: ^4.4.3\n"
            "        version: 4.4.3\n"
            "    devDependencies:\n"
            "      typescript:\n"
            "        specifier: ^5.9.3\n"
            "        version: 5.9.3\n\npackages:\n"),
        "node_modules/zod/package.json":
            '{"name":"zod","version":"4.4.3"}',
        "node_modules/zod/v4/package.json":
            '{"name":"zod-v4","version":"4.0.0"}',
        "node_modules/zod/locales/package.json":
            '{"name":"zod-locales","version":"0.0.2"}',
        "node_modules/zod/src/index.ts": "export const z = 1;\n",
        "node_modules/zod/lib/index.js": "module.exports = {};\n",
        "node_modules/@modelcontextprotocol/sdk/package.json":
            '{"name":"@modelcontextprotocol/sdk","version":"1.29.0"}',
        "node_modules/@types/node/package.json":
            '{"name":"@types/node","version":"20.19.43"}',
        "node_modules/esbuild/package.json":
            '{"name":"esbuild","version":"0.28.1"}',
        "node_modules/tsx/package.json": '{"name":"tsx","version":"4.22.4"}',
        "node_modules/typescript/package.json":
            '{"name":"typescript","version":"5.9.3"}',
    })
    rows = sbom_components(tmp / "shape-pnpm.md", pnpm)
    deps = sorted(name for name, scope in rows or [] if scope != "system")
    r.check(
        rows is not None
        and deps == [
            "@modelcontextprotocol/sdk", "@types/node",
            "esbuild", "tsx", "typescript", "zod",
        ],
        "pnpm-workspace shape registers exactly its declared packages "
        "(no subpackage or source-tree components)",
    )

    go = tmp / "shape-go"
    write_fixture(go, {
        "alire.toml": 'name = "shapego"\nversion = "1.0.0"\n',
        "go.mod": (
            "module example.com/shapego\n\ngo 1.24\n\n"
            "require github.com/spf13/cobra v1.9.1\n\n"
            "require (\n"
            "\tgolang.org/x/sync v0.12.0 // indirect\n"
            "\tgithub.com/stretchr/testify v1.10.0 // indirect\n"
            ")\n\n"
            "// require github.com/commented/out v1.0.0\n"
            "replace github.com/old/pkg => github.com/new/pkg v1.0.0\n"),
    })
    rows = sbom_components(tmp / "shape-go.md", go)
    scopes = {name: scope for name, scope in rows or [] if scope != "system"}
    r.check(
        rows is not None
        and scopes == {
            "github.com/spf13/cobra": "base",
            "github.com/stretchr/testify": "test",
            "golang.org/x/sync": "transitive",
        },
        "Go-module shape registers base/transitive/test scopes and no "
        "replace or commented-out module",
    )

def check_sbom_siblings(r: Results, tmp: Path) -> None:
    """Run `sbom` over the real sibling projects present on this machine.

    The shape fixtures above pin the parser in miniature; these checks run
    the    whole pipeline over real workspaces, where a directory walk, a
    lockfile, or a scope rule regresses first. Each project must produce a
    component table with known scopes, no duplicate component, no invented
    licence or source link on a system row, no component from an ecosystem
    the project does not declare, and npm components for an npm workspace.
    A missing sibling is skipped.

    Versions and licences are not asserted: they can come from the package
    registry, so they depend on the network and on the host's cache.
    """
    for name, ecosystems in SBOM_SIBLINGS:
        target = ROOT.parent / name
        if not target.is_dir():
            r.skip(f"../{name} sbom checks", "the sibling is not checked out")
            continue
        rows = sbom_table(target, tmp / f"sibling-{name}.md")
        r.check(rows is not None and rows != [],
                f"../{name}: sbom writes a component table")
        if not rows:
            continue
        scopes = {row.get("scope", "") for row in rows}
        r.check(scopes <= set(SBOM_SCOPES),
                f"../{name}: every component carries a known scope")
        system = [row for row in rows if row.get("scope") == "system"]
        r.check(all(row.get("purl", "").startswith("pkg:generic/")
                    for row in system),
                f"../{name}: a system component carries a generic purl")
        r.check(all(row.get("license") == "NOASSERTION"
                    and row.get("source") == "-" for row in system),
                f"../{name}: a system row invents no licence or source link")
        foreign = sorted({
            row.get("purl", "") for row in rows
            if row.get("purl", "").startswith("pkg:")
            and not row.get("purl", "").startswith("pkg:generic/")
            and not any(row.get("purl", "").startswith(prefix)
                        for prefix in ecosystems)
        })
        r.check(not foreign,
                f"../{name}: no component claims an undeclared ecosystem"
                + (f" ({', '.join(foreign)})" if foreign else ""))
        names = [row.get("component", "") for row in rows]
        r.check(len(names) == len(set(names)),
                f"../{name}: no component is listed twice")
        forbidden = [row.get("component", "") for row in system
                     if row.get("component", "") in
                     SBOM_FORBIDDEN_TOOLS.get(name, ())]
        r.check(not forbidden,
                f"../{name}: no system component for an unused toolkit"
                + (f" ({', '.join(forbidden)})" if forbidden else ""))
        npm = [row for row in rows
               if row.get("purl", "").startswith("pkg:npm/")]
        if "pkg:npm/" in ecosystems:
            r.check(bool(npm),
                    f"../{name}: the npm workspace registers npm components")

def check_target_equivalence(r: Results, tmp: Path) -> None:
    #  `status` exits 1 when the host cannot prove (its readiness line), which
    #  says nothing about the target flags: assert the documented exit codes
    #  and the report, not a bare 0 that only a provisioned host reaches.
    short = run(["status", "-t", str(tmp)])
    long = run(["status", f"--target={tmp}"])
    r.check(
        short.returncode in (0, 1) and long.returncode in (0, 1),
        "status accepts -t and --target",
    )
    r.check(
        target_line(short.stdout) is not None
        and target_line(short.stdout) == target_line(long.stdout),
        "-t resolves the same target as --target",
    )

def check_markdown_output(r: Results, tmp: Path) -> None:
    # An empty target reports DAL Unmet, so the exit code is 1 by design; the
    # reports must still be written.
    plain = run(["-t", str(tmp), "--no-sbom", "--no-svg", "--emit-md",
                 "--no-cache"], timeout=300)
    docs = tmp / "docs"
    r.check(
        plain.returncode in (0, 1)
        and (docs / "VERIFICATION.md").is_file()
        and (docs / "TRACE.md").is_file(),
        "bare --emit-md writes VERIFICATION.md + TRACE.md to <target>/docs",
    )
    for name in ("VERIFICATION.md", "TRACE.md"):
        (docs / name).unlink()
    suppressed = run(["-t", str(tmp), "--no-sbom", "--no-svg", "--emit-md",
                      "--no-md", "--no-cache"], timeout=300)
    r.check(
        suppressed.returncode in (0, 1)
        and not (docs / "VERIFICATION.md").exists(),
        "--no-md overrides --emit-md",
    )
