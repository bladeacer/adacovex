// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="index.html"><strong aria-hidden="true">1.</strong> Adacovex manual</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="installation.html"><strong aria-hidden="true">2.</strong> Installing adacovex</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cli-reference.html"><strong aria-hidden="true">3.</strong> adacovex CLI Reference</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="target-projects.html"><strong aria-hidden="true">4.</strong> Target project requirements</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="dashboard.html"><strong aria-hidden="true">5.</strong> Web dashboard and JSON API</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="sbom.html"><strong aria-hidden="true">6.</strong> The sbom subcommand</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="standards.html"><strong aria-hidden="true">7.</strong> Compliance Standards (DO-178C / ISO 26262 / IEC 62304)</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="platforms.html"><strong aria-hidden="true">8.</strong> Platform support</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="vcs.html"><strong aria-hidden="true">9.</strong> VCS support and differential assessment</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="ci-cd.html"><strong aria-hidden="true">10.</strong> adacovex CI/CD</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="developer-guide.html"><strong aria-hidden="true">11.</strong> Contributor guide: codebase structure and setup</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="proving.html"><strong aria-hidden="true">12.</strong> Proving and writing SPARK proofs</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="architecture.html"><strong aria-hidden="true">13.</strong> adacovex Architecture Decisions</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="requirements.html"><strong aria-hidden="true">14.</strong> Dependencies</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="perf.html"><strong aria-hidden="true">15.</strong> Performance</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="ste100-technical-names.html"><strong aria-hidden="true">16.</strong> STE100 Technical Names for adacovex</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="llm-usage.html"><strong aria-hidden="true">17.</strong> AI / LLM Usage in this Project</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="HLR.html"><strong aria-hidden="true">18.</strong> HLR index</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="LLR.html"><strong aria-hidden="true">19.</strong> LLR mapping</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="proof/index.html"><strong aria-hidden="true">20.</strong> Proof ledger</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="proof/16.1.0-ledger.html"><strong aria-hidden="true">20.1.</strong> 16.1.0 proof ledger</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="compliance/index.html"><strong aria-hidden="true">21.</strong> Compliance outputs</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="compliance/HLR.html"><strong aria-hidden="true">21.1.</strong> HLR index</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="compliance/LLR.html"><strong aria-hidden="true">21.2.</strong> LLR mapping</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="compliance/VERIFICATION.html"><strong aria-hidden="true">21.3.</strong> Verification report</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="compliance/TRACE.html"><strong aria-hidden="true">21.4.</strong> Traceability matrix</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="badges/index.html"><strong aria-hidden="true">22.</strong> Badges</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="test_result.html"><strong aria-hidden="true">23.</strong> Test report</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/index.html"><strong aria-hidden="true">24.</strong> API reference</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-docstring-spec.html"><strong aria-hidden="true">24.1.</strong> Docstring Annotation Specification</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-test-format.html"><strong aria-hidden="true">24.2.</strong> Supported Test Result Formats</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-spark-levels.html"><strong aria-hidden="true">24.3.</strong> SPARK Assurance Levels</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-dal-levels.html"><strong aria-hidden="true">24.4.</strong> DO-178C DAL Levels</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-asil-levels.html"><strong aria-hidden="true">24.5.</strong> ISO 26262 ASIL Levels</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-class-levels.html"><strong aria-hidden="true">24.6.</strong> IEC 62304 Software Safety Classes</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-ansi.html"><strong aria-hidden="true">24.7.</strong> Adacovex.Ansi</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-cache-serialization.html"><strong aria-hidden="true">24.8.</strong> Adacovex.Cache.Serialization</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-cache.html"><strong aria-hidden="true">24.9.</strong> Adacovex.Cache</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-completion.html"><strong aria-hidden="true">24.10.</strong> Adacovex.Completion</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-complexity.html"><strong aria-hidden="true">24.11.</strong> Adacovex.Complexity</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-compliance-dal.html"><strong aria-hidden="true">24.12.</strong> Adacovex.Compliance.DAL</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-compliance.html"><strong aria-hidden="true">24.13.</strong> Adacovex.Compliance</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-config-testing.html"><strong aria-hidden="true">24.14.</strong> Adacovex.Config.Testing</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-config.html"><strong aria-hidden="true">24.15.</strong> Adacovex.Config</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-core.html"><strong aria-hidden="true">24.16.</strong> Adacovex.Core</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-cpus.html"><strong aria-hidden="true">24.17.</strong> Adacovex.CPUs</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-dashboard_template.html"><strong aria-hidden="true">24.18.</strong> Adacovex.Dashboard_Template</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-diff.html"><strong aria-hidden="true">24.19.</strong> Adacovex.Diff</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-docs_template.html"><strong aria-hidden="true">24.20.</strong> Adacovex.Docs_Template</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-ir_bounds.html"><strong aria-hidden="true">24.21.</strong> Adacovex.IR_Bounds</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-ir_synthesiser.html"><strong aria-hidden="true">24.22.</strong> Adacovex.IR_Synthesiser</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers-do178c.html"><strong aria-hidden="true">24.23.</strong> Adacovex.Parsers.DO178C</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers-gnatprove.html"><strong aria-hidden="true">24.24.</strong> Adacovex.Parsers.GNATprove</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers-manifest.html"><strong aria-hidden="true">24.25.</strong> Adacovex.Parsers.Manifest</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers-source.html"><strong aria-hidden="true">24.26.</strong> Adacovex.Parsers.Source</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers-tests.html"><strong aria-hidden="true">24.27.</strong> Adacovex.Parsers.Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-parsers.html"><strong aria-hidden="true">24.28.</strong> Adacovex.Parsers</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-prove.html"><strong aria-hidden="true">24.29.</strong> Adacovex.Prove</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-prove_patch.html"><strong aria-hidden="true">24.30.</strong> Adacovex.Prove_Patch</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-ansi.html"><strong aria-hidden="true">24.31.</strong> Adacovex.Renderers.ANSI</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-html.html"><strong aria-hidden="true">24.32.</strong> Adacovex.Renderers.HTML</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-man.html"><strong aria-hidden="true">24.33.</strong> Adacovex.Renderers.Man</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-markdown.html"><strong aria-hidden="true">24.34.</strong> Adacovex.Renderers.Markdown</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-sbom.html"><strong aria-hidden="true">24.35.</strong> Adacovex.Renderers.SBOM</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers-svg.html"><strong aria-hidden="true">24.36.</strong> Adacovex.Renderers.SVG</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-renderers.html"><strong aria-hidden="true">24.37.</strong> Adacovex.Renderers</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-server-http.html"><strong aria-hidden="true">24.38.</strong> Adacovex.Server.HTTP</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-server-router.html"><strong aria-hidden="true">24.39.</strong> Adacovex.Server.Router</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-server.html"><strong aria-hidden="true">24.40.</strong> Adacovex.Server</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-target_profiles.html"><strong aria-hidden="true">24.41.</strong> Adacovex.Target_Profiles</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-timezones.html"><strong aria-hidden="true">24.42.</strong> Adacovex.Timezones</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-types-implementation.html"><strong aria-hidden="true">24.43.</strong> Adacovex.Types.Implementation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-types.html"><strong aria-hidden="true">24.44.</strong> Adacovex.Types</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex-vcs.html"><strong aria-hidden="true">24.45.</strong> Adacovex.VCS</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex.html"><strong aria-hidden="true">24.46.</strong> Adacovex</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_complexity_tests.html"><strong aria-hidden="true">24.47.</strong> Adacovex_Complexity_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_config_tests.html"><strong aria-hidden="true">24.48.</strong> Adacovex_Config_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_dal_tests.html"><strong aria-hidden="true">24.49.</strong> Adacovex_DAL_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_ir_tests.html"><strong aria-hidden="true">24.50.</strong> Adacovex_IR_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_man_tests.html"><strong aria-hidden="true">24.51.</strong> Adacovex_Man_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_prove_patch_tests.html"><strong aria-hidden="true">24.52.</strong> Adacovex_Prove_Patch_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_prove_tests.html"><strong aria-hidden="true">24.53.</strong> Adacovex_Prove_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_renderer_svg_tests.html"><strong aria-hidden="true">24.54.</strong> Adacovex_Renderer_SVG_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_renderer_tests.html"><strong aria-hidden="true">24.55.</strong> Adacovex_Renderer_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_sbom_tests.html"><strong aria-hidden="true">24.56.</strong> Adacovex_SBOM_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_scanner_tests.html"><strong aria-hidden="true">24.57.</strong> Adacovex_Scanner_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_server_tests.html"><strong aria-hidden="true">24.58.</strong> Adacovex_Server_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_testparser_tests.html"><strong aria-hidden="true">24.59.</strong> Adacovex_TestParser_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_types_tests.html"><strong aria-hidden="true">24.60.</strong> Adacovex_Types_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_tz_ansi_tests.html"><strong aria-hidden="true">24.61.</strong> Adacovex_TZ_ANSI_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_vcs_tests.html"><strong aria-hidden="true">24.62.</strong> Adacovex_VCS_Tests</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="api-docs/adacovex_version_info.html"><strong aria-hidden="true">24.63.</strong> Adacovex_Version_Info</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/index.html"><strong aria-hidden="true">25.</strong> Changelogs</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.38.0.html"><strong aria-hidden="true">25.1.</strong> adacovex 1.38.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.37.0.html"><strong aria-hidden="true">25.2.</strong> adacovex 1.37.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.36.0.html"><strong aria-hidden="true">25.3.</strong> adacovex 1.36.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.35.0.html"><strong aria-hidden="true">25.4.</strong> adacovex 1.35.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.34.0.html"><strong aria-hidden="true">25.5.</strong> adacovex 1.34.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.33.0.html"><strong aria-hidden="true">25.6.</strong> adacovex 1.33.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.32.0.html"><strong aria-hidden="true">25.7.</strong> adacovex 1.32.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.31.0.html"><strong aria-hidden="true">25.8.</strong> adacovex 1.31.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.30.0.html"><strong aria-hidden="true">25.9.</strong> adacovex 1.30.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.29.0.html"><strong aria-hidden="true">25.10.</strong> adacovex 1.29.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.28.0.html"><strong aria-hidden="true">25.11.</strong> adacovex 1.28.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.27.0.html"><strong aria-hidden="true">25.12.</strong> adacovex 1.27.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.26.0.html"><strong aria-hidden="true">25.13.</strong> adacovex 1.26.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.25.0.html"><strong aria-hidden="true">25.14.</strong> adacovex 1.25.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.24.0.html"><strong aria-hidden="true">25.15.</strong> adacovex 1.24.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.23.0.html"><strong aria-hidden="true">25.16.</strong> adacovex 1.23.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.22.0.html"><strong aria-hidden="true">25.17.</strong> adacovex 1.22.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.21.0.html"><strong aria-hidden="true">25.18.</strong> adacovex 1.21.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.20.0.html"><strong aria-hidden="true">25.19.</strong> adacovex 1.20.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.19.0.html"><strong aria-hidden="true">25.20.</strong> adacovex 1.19.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.18.0.html"><strong aria-hidden="true">25.21.</strong> adacovex 1.18.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.17.0.html"><strong aria-hidden="true">25.22.</strong> adacovex 1.17.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.16.0.html"><strong aria-hidden="true">25.23.</strong> adacovex 1.16.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.15.0.html"><strong aria-hidden="true">25.24.</strong> adacovex 1.15.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.14.0.html"><strong aria-hidden="true">25.25.</strong> adacovex 1.14.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.13.0.html"><strong aria-hidden="true">25.26.</strong> adacovex 1.13.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.12.0.html"><strong aria-hidden="true">25.27.</strong> adacovex 1.12.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.11.0.html"><strong aria-hidden="true">25.28.</strong> adacovex 1.11.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.10.0.html"><strong aria-hidden="true">25.29.</strong> adacovex 1.10.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.9.0.html"><strong aria-hidden="true">25.30.</strong> adacovex 1.9.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.8.0.html"><strong aria-hidden="true">25.31.</strong> adacovex 1.8.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.7.0.html"><strong aria-hidden="true">25.32.</strong> adacovex 1.7.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.6.0.html"><strong aria-hidden="true">25.33.</strong> adacovex 1.6.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.5.0.html"><strong aria-hidden="true">25.34.</strong> adacovex 1.5.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.4.0.html"><strong aria-hidden="true">25.35.</strong> adacovex 1.4.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.3.0.html"><strong aria-hidden="true">25.36.</strong> adacovex 1.3.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.1.0.html"><strong aria-hidden="true">25.37.</strong> adacovex 1.1.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-1.0.0.html"><strong aria-hidden="true">25.38.</strong> adacovex 1.0.0</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="changelogs/adacovex-0.1.0.html"><strong aria-hidden="true">25.39.</strong> adacovex 0.1.0</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="CREDITS.html"><strong aria-hidden="true">26.</strong> Credits</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="THIRD_PARTY_NOTICES.html"><strong aria-hidden="true">27.</strong> Third-party notices</a></span></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split('#')[0].split('?')[0];
        if (current_page.endsWith('/')) {
            current_page += 'index.html';
        }
        const links = Array.prototype.slice.call(this.querySelectorAll('a'));
        const l = links.length;
        for (let i = 0; i < l; ++i) {
            const link = links[i];
            const href = link.getAttribute('href');
            if (href && !href.startsWith('#') && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The 'index' page is supposed to alias the first chapter in the book.
            // Check both with and without the '.html' suffix to be robust against pretty URLs
            if (link.href.replace(/\.html$/, '') === current_page.replace(/\.html$/, '')
                || i === 0
                && path_to_root === ''
                && current_page.endsWith('/index.html')) {
                link.classList.add('active');
                let parent = link.parentElement;
                while (parent) {
                    if (parent.tagName === 'LI' && parent.classList.contains('chapter-item')) {
                        parent.classList.add('expanded');
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', e => {
            if (e.target.tagName === 'A') {
                const clientRect = e.target.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                sessionStorage.setItem('sidebar-scroll-offset', clientRect.top - sidebarRect.top);
            }
        }, { passive: true });
        const sidebarScrollOffset = sessionStorage.getItem('sidebar-scroll-offset');
        sessionStorage.removeItem('sidebar-scroll-offset');
        if (sidebarScrollOffset !== null) {
            // preserve sidebar scroll position when navigating via links within sidebar
            const activeSection = this.querySelector('.active');
            if (activeSection) {
                const clientRect = activeSection.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                const currentOffset = clientRect.top - sidebarRect.top;
                this.scrollTop += currentOffset - parseFloat(sidebarScrollOffset);
            }
        } else {
            // scroll sidebar to current active section when navigating via
            // 'next/previous chapter' buttons
            const activeSection = document.querySelector('#mdbook-sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        const sidebarAnchorToggles = document.querySelectorAll('.chapter-fold-toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(el => {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define('mdbook-sidebar-scrollbox', MDBookSidebarScrollbox);


// ---------------------------------------------------------------------------
// Support for dynamically adding headers to the sidebar.

(function() {
    // This is used to detect which direction the page has scrolled since the
    // last scroll event.
    let lastKnownScrollPosition = 0;
    // This is the threshold in px from the top of the screen where it will
    // consider a header the "current" header when scrolling down.
    const defaultDownThreshold = 150;
    // Same as defaultDownThreshold, except when scrolling up.
    const defaultUpThreshold = 300;
    // The threshold is a virtual horizontal line on the screen where it
    // considers the "current" header to be above the line. The threshold is
    // modified dynamically to handle headers that are near the bottom of the
    // screen, and to slightly offset the behavior when scrolling up vs down.
    let threshold = defaultDownThreshold;
    // This is used to disable updates while scrolling. This is needed when
    // clicking the header in the sidebar, which triggers a scroll event. It
    // is somewhat finicky to detect when the scroll has finished, so this
    // uses a relatively dumb system of disabling scroll updates for a short
    // time after the click.
    let disableScroll = false;
    // Array of header elements on the page.
    let headers;
    // Array of li elements that are initially collapsed headers in the sidebar.
    // I'm not sure why eslint seems to have a false positive here.
    // eslint-disable-next-line prefer-const
    let headerToggles = [];
    // This is a debugging tool for the threshold which you can enable in the console.
    let thresholdDebug = false;

    // Updates the threshold based on the scroll position.
    function updateThreshold() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const windowHeight = window.innerHeight;
        const documentHeight = document.documentElement.scrollHeight;

        // The number of pixels below the viewport, at most documentHeight.
        // This is used to push the threshold down to the bottom of the page
        // as the user scrolls towards the bottom.
        const pixelsBelow = Math.max(0, documentHeight - (scrollTop + windowHeight));
        // The number of pixels above the viewport, at least defaultDownThreshold.
        // Similar to pixelsBelow, this is used to push the threshold back towards
        // the top when reaching the top of the page.
        const pixelsAbove = Math.max(0, defaultDownThreshold - scrollTop);
        // How much the threshold should be offset once it gets close to the
        // bottom of the page.
        const bottomAdd = Math.max(0, windowHeight - pixelsBelow - defaultDownThreshold);
        let adjustedBottomAdd = bottomAdd;

        // Adjusts bottomAdd for a small document. The calculation above
        // assumes the document is at least twice the windowheight in size. If
        // it is less than that, then bottomAdd needs to be shrunk
        // proportional to the difference in size.
        if (documentHeight < windowHeight * 2) {
            const maxPixelsBelow = documentHeight - windowHeight;
            const t = 1 - pixelsBelow / Math.max(1, maxPixelsBelow);
            const clamp = Math.max(0, Math.min(1, t));
            adjustedBottomAdd *= clamp;
        }

        let scrollingDown = true;
        if (scrollTop < lastKnownScrollPosition) {
            scrollingDown = false;
        }

        if (scrollingDown) {
            // When scrolling down, move the threshold up towards the default
            // downwards threshold position. If near the bottom of the page,
            // adjustedBottomAdd will offset the threshold towards the bottom
            // of the page.
            const amountScrolledDown = scrollTop - lastKnownScrollPosition;
            const adjustedDefault = defaultDownThreshold + adjustedBottomAdd;
            threshold = Math.max(adjustedDefault, threshold - amountScrolledDown);
        } else {
            // When scrolling up, move the threshold down towards the default
            // upwards threshold position. If near the bottom of the page,
            // quickly transition the threshold back up where it normally
            // belongs.
            const amountScrolledUp = lastKnownScrollPosition - scrollTop;
            const adjustedDefault = defaultUpThreshold - pixelsAbove
                + Math.max(0, adjustedBottomAdd - defaultDownThreshold);
            threshold = Math.min(adjustedDefault, threshold + amountScrolledUp);
        }

        if (documentHeight <= windowHeight) {
            threshold = 0;
        }

        if (thresholdDebug) {
            const id = 'mdbook-threshold-debug-data';
            let data = document.getElementById(id);
            if (data === null) {
                data = document.createElement('div');
                data.id = id;
                data.style.cssText = `
                    position: fixed;
                    top: 50px;
                    right: 10px;
                    background-color: 0xeeeeee;
                    z-index: 9999;
                    pointer-events: none;
                `;
                document.body.appendChild(data);
            }
            data.innerHTML = `
                <table>
                  <tr><td>documentHeight</td><td>${documentHeight.toFixed(1)}</td></tr>
                  <tr><td>windowHeight</td><td>${windowHeight.toFixed(1)}</td></tr>
                  <tr><td>scrollTop</td><td>${scrollTop.toFixed(1)}</td></tr>
                  <tr><td>pixelsAbove</td><td>${pixelsAbove.toFixed(1)}</td></tr>
                  <tr><td>pixelsBelow</td><td>${pixelsBelow.toFixed(1)}</td></tr>
                  <tr><td>bottomAdd</td><td>${bottomAdd.toFixed(1)}</td></tr>
                  <tr><td>adjustedBottomAdd</td><td>${adjustedBottomAdd.toFixed(1)}</td></tr>
                  <tr><td>scrollingDown</td><td>${scrollingDown}</td></tr>
                  <tr><td>threshold</td><td>${threshold.toFixed(1)}</td></tr>
                </table>
            `;
            drawDebugLine();
        }

        lastKnownScrollPosition = scrollTop;
    }

    function drawDebugLine() {
        if (!document.body) {
            return;
        }
        const id = 'mdbook-threshold-debug-line';
        const existingLine = document.getElementById(id);
        if (existingLine) {
            existingLine.remove();
        }
        const line = document.createElement('div');
        line.id = id;
        line.style.cssText = `
            position: fixed;
            top: ${threshold}px;
            left: 0;
            width: 100vw;
            height: 2px;
            background-color: red;
            z-index: 9999;
            pointer-events: none;
        `;
        document.body.appendChild(line);
    }

    function mdbookEnableThresholdDebug() {
        thresholdDebug = true;
        updateThreshold();
        drawDebugLine();
    }

    window.mdbookEnableThresholdDebug = mdbookEnableThresholdDebug;

    // Updates which headers in the sidebar should be expanded. If the current
    // header is inside a collapsed group, then it, and all its parents should
    // be expanded.
    function updateHeaderExpanded(currentA) {
        // Add expanded to all header-item li ancestors.
        let current = currentA.parentElement;
        while (current) {
            if (current.tagName === 'LI' && current.classList.contains('header-item')) {
                current.classList.add('expanded');
            }
            current = current.parentElement;
        }
    }

    // Updates which header is marked as the "current" header in the sidebar.
    // This is done with a virtual Y threshold, where headers at or below
    // that line will be considered the current one.
    function updateCurrentHeader() {
        if (!headers || !headers.length) {
            return;
        }

        // Reset the classes, which will be rebuilt below.
        const els = document.getElementsByClassName('current-header');
        for (const el of els) {
            el.classList.remove('current-header');
        }
        for (const toggle of headerToggles) {
            toggle.classList.remove('expanded');
        }

        // Find the last header that is above the threshold.
        let lastHeader = null;
        for (const header of headers) {
            const rect = header.getBoundingClientRect();
            if (rect.top <= threshold) {
                lastHeader = header;
            } else {
                break;
            }
        }
        if (lastHeader === null) {
            lastHeader = headers[0];
            const rect = lastHeader.getBoundingClientRect();
            const windowHeight = window.innerHeight;
            if (rect.top >= windowHeight) {
                return;
            }
        }

        // Get the anchor in the summary.
        const href = '#' + lastHeader.id;
        const a = [...document.querySelectorAll('.header-in-summary')]
            .find(element => element.getAttribute('href') === href);
        if (!a) {
            return;
        }

        a.classList.add('current-header');

        updateHeaderExpanded(a);
    }

    // Updates which header is "current" based on the threshold line.
    function reloadCurrentHeader() {
        if (disableScroll) {
            return;
        }
        updateThreshold();
        updateCurrentHeader();
    }


    // When clicking on a header in the sidebar, this adjusts the threshold so
    // that it is located next to the header. This is so that header becomes
    // "current".
    function headerThresholdClick(event) {
        // See disableScroll description why this is done.
        disableScroll = true;
        setTimeout(() => {
            disableScroll = false;
        }, 100);
        // requestAnimationFrame is used to delay the update of the "current"
        // header until after the scroll is done, and the header is in the new
        // position.
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                // Closest is needed because if it has child elements like <code>.
                const a = event.target.closest('a');
                const href = a.getAttribute('href');
                const targetId = href.substring(1);
                const targetElement = document.getElementById(targetId);
                if (targetElement) {
                    threshold = targetElement.getBoundingClientRect().bottom;
                    updateCurrentHeader();
                }
            });
        });
    }

    // Takes the nodes from the given head and copies them over to the
    // destination, along with some filtering.
    function filterHeader(source, dest) {
        const clone = source.cloneNode(true);
        clone.querySelectorAll('mark').forEach(mark => {
            mark.replaceWith(...mark.childNodes);
        });
        dest.append(...clone.childNodes);
    }

    // Scans page for headers and adds them to the sidebar.
    document.addEventListener('DOMContentLoaded', function() {
        const activeSection = document.querySelector('#mdbook-sidebar .active');
        if (activeSection === null) {
            return;
        }

        const main = document.getElementsByTagName('main')[0];
        headers = Array.from(main.querySelectorAll('h2, h3, h4, h5, h6'))
            .filter(h => h.id !== '' && h.children.length && h.children[0].tagName === 'A');

        if (headers.length === 0) {
            return;
        }

        // Build a tree of headers in the sidebar.

        const stack = [];

        const firstLevel = parseInt(headers[0].tagName.charAt(1));
        for (let i = 1; i < firstLevel; i++) {
            const ol = document.createElement('ol');
            ol.classList.add('section');
            if (stack.length > 0) {
                stack[stack.length - 1].ol.appendChild(ol);
            }
            stack.push({level: i + 1, ol: ol});
        }

        // The level where it will start folding deeply nested headers.
        const foldLevel = 3;

        for (let i = 0; i < headers.length; i++) {
            const header = headers[i];
            const level = parseInt(header.tagName.charAt(1));

            const currentLevel = stack[stack.length - 1].level;
            if (level > currentLevel) {
                // Begin nesting to this level.
                for (let nextLevel = currentLevel + 1; nextLevel <= level; nextLevel++) {
                    const ol = document.createElement('ol');
                    ol.classList.add('section');
                    const last = stack[stack.length - 1];
                    const lastChild = last.ol.lastChild;
                    // Handle the case where jumping more than one nesting
                    // level, which doesn't have a list item to place this new
                    // list inside of.
                    if (lastChild) {
                        lastChild.appendChild(ol);
                    } else {
                        last.ol.appendChild(ol);
                    }
                    stack.push({level: nextLevel, ol: ol});
                }
            } else if (level < currentLevel) {
                while (stack.length > 1 && stack[stack.length - 1].level > level) {
                    stack.pop();
                }
            }

            const li = document.createElement('li');
            li.classList.add('header-item');
            li.classList.add('expanded');
            if (level < foldLevel) {
                li.classList.add('expanded');
            }
            const span = document.createElement('span');
            span.classList.add('chapter-link-wrapper');
            const a = document.createElement('a');
            span.appendChild(a);
            a.href = '#' + header.id;
            a.classList.add('header-in-summary');
            filterHeader(header.children[0], a);
            a.addEventListener('click', headerThresholdClick);
            const nextHeader = headers[i + 1];
            if (nextHeader !== undefined) {
                const nextLevel = parseInt(nextHeader.tagName.charAt(1));
                if (nextLevel > level && level >= foldLevel) {
                    const toggle = document.createElement('a');
                    toggle.classList.add('chapter-fold-toggle');
                    toggle.classList.add('header-toggle');
                    toggle.addEventListener('click', () => {
                        li.classList.toggle('expanded');
                    });
                    const toggleDiv = document.createElement('div');
                    toggleDiv.textContent = '❱';
                    toggle.appendChild(toggleDiv);
                    span.appendChild(toggle);
                    headerToggles.push(li);
                }
            }
            li.appendChild(span);

            const currentParent = stack[stack.length - 1];
            currentParent.ol.appendChild(li);
        }

        const onThisPage = document.createElement('div');
        onThisPage.classList.add('on-this-page');
        onThisPage.append(stack[0].ol);
        const activeItemSpan = activeSection.parentElement;
        activeItemSpan.after(onThisPage);
    });

    document.addEventListener('DOMContentLoaded', reloadCurrentHeader);
    document.addEventListener('scroll', reloadCurrentHeader, { passive: true });
})();

