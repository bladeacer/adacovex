# adacovex API Reference

## How to read this reference

This reference documents the Ada packages that implement adacovex.
It is generated from the source docstrings by `make doc`.

- **End users** need the CLI reference, the dashboard guide, and
  the standards pages.  The [CLI reference](../usage/cli-reference.md)
  describes every flag.  The [standards guide](../usage/standards.md)
  explains the compliance levels.
- **Contributors** use this reference together with the
  [contributing guide](
  https://github.com/bladeacer/adacovex/blob/main/CONTRIBUTING.md)
  and the [architecture notes](../contributing/architecture.md).  The
  [docstring spec](adacovex-docstring-spec.md) defines the
  annotation format.
- **Maintainers** read the [proof ledger](../proof/index.md) for the
  verified-VC history and the [changelogs](../changelogs/index.md)
  for the release history.

Technical terms follow the controlled dictionary in
[STE100 Technical Names](../contributing/ste100-technical-names.md).  All
documentation, including these pages, uses British English and
ASD-STE100 Simplified Technical English.  A word not in the
dictionary means the sentence is not yet STE100-clean.

## Guides

- [Docstring Spec](adacovex-docstring-spec.md)
- [Test Result Formats](adacovex-test-format.md)
- [SPARK Assurance Levels](adacovex-spark-levels.md)
- [DO-178C DAL Levels](adacovex-dal-levels.md)
- [ISO 26262 ASIL Levels](adacovex-asil-levels.md)
- [IEC 62304 Safety Classes](adacovex-class-levels.md)

## Packages

- [Adacovex](adacovex.md)
- [Adacovex_Cache_Tests](adacovex_cache_tests.md)
- [Adacovex_Complexity_Tests](adacovex_complexity_tests.md)
- [Adacovex_Config_Tests](adacovex_config_tests.md)
- [Adacovex_DAL_Tests](adacovex_dal_tests.md)
- [Adacovex_IR_Tests](adacovex_ir_tests.md)
- [Adacovex_Man_Tests](adacovex_man_tests.md)
- [Adacovex_Prove_Patch_Tests](adacovex_prove_patch_tests.md)
- [Adacovex_Prove_Tests](adacovex_prove_tests.md)
- [Adacovex_Renderer_SVG_Tests](adacovex_renderer_svg_tests.md)
- [Adacovex_Renderer_Tests](adacovex_renderer_tests.md)
- [Adacovex_SBOM_Tests](adacovex_sbom_tests.md)
- [Adacovex_Scanner_Tests](adacovex_scanner_tests.md)
- [Adacovex_Server_Tests](adacovex_server_tests.md)
- [Adacovex_TestParser_Tests](adacovex_testparser_tests.md)
- [Adacovex_Types_Tests](adacovex_types_tests.md)
- [Adacovex_TZ_ANSI_Tests](adacovex_tz_ansi_tests.md)
- [Adacovex_VCS_Tests](adacovex_vcs_tests.md)
- [Adacovex_Version_Info](adacovex_version_info.md)
- [Adacovex.Ansi](adacovex-ansi.md)
- [Adacovex.Cache](adacovex-cache.md)
- [Adacovex.Completion](adacovex-completion.md)
- [Adacovex.Complexity](adacovex-complexity.md)
- [Adacovex.Compliance](adacovex-compliance.md)
- [Adacovex.Config](adacovex-config.md)
- [Adacovex.Core](adacovex-core.md)
- [Adacovex.CPUs](adacovex-cpus.md)
- [Adacovex.Dashboard_Template](adacovex-dashboard_template.md)
- [Adacovex.Diff](adacovex-diff.md)
- [Adacovex.Dir_Cache](adacovex-dir_cache.md)
- [Adacovex.Docs_Template](adacovex-docs_template.md)
- [Adacovex.IR_Bounds](adacovex-ir_bounds.md)
- [Adacovex.IR_Synthesiser](adacovex-ir_synthesiser.md)
- [Adacovex.Opt_Outs](adacovex-opt_outs.md)
- [Adacovex.Parsers](adacovex-parsers.md)
- [Adacovex.Prove](adacovex-prove.md)
- [Adacovex.Prove_Patch](adacovex-prove_patch.md)
- [Adacovex.Renderers](adacovex-renderers.md)
- [Adacovex.Server](adacovex-server.md)
- [Adacovex.Target_Profiles](adacovex-target_profiles.md)
- [Adacovex.Timezones](adacovex-timezones.md)
- [Adacovex.Types](adacovex-types.md)
- [Adacovex.VCS](adacovex-vcs.md)
- [Adacovex.Cache.Serialization](adacovex-cache-serialization.md)
- [Adacovex.Compliance.DAL](adacovex-compliance-dal.md)
- [Adacovex.Config.Testing](adacovex-config-testing.md)
- [Adacovex.Parsers.DO178C](adacovex-parsers-do178c.md)
- [Adacovex.Parsers.GNATprove](adacovex-parsers-gnatprove.md)
- [Adacovex.Parsers.Manifest](adacovex-parsers-manifest.md)
- [Adacovex.Parsers.Source](adacovex-parsers-source.md)
- [Adacovex.Parsers.Tests](adacovex-parsers-tests.md)
- [Adacovex.Renderers.ANSI](adacovex-renderers-ansi.md)
- [Adacovex.Renderers.HTML](adacovex-renderers-html.md)
- [Adacovex.Renderers.Man](adacovex-renderers-man.md)
- [Adacovex.Renderers.Markdown](adacovex-renderers-markdown.md)
- [Adacovex.Renderers.SBOM](adacovex-renderers-sbom.md)
- [Adacovex.Renderers.SVG](adacovex-renderers-svg.md)
- [Adacovex.Server.HTTP](adacovex-server-http.md)
- [Adacovex.Server.Router](adacovex-server-router.md)
- [Adacovex.Types.Implementation](adacovex-types-implementation.md)
