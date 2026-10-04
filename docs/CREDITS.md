# Credits

bladeacer develops and maintains adacovex.

## SimpleEnglish skill

The documentation discipline of this project is the ASD-STE100 Simplified
Technical English standard. The rules come from the
[SimpleEnglish skill](https://github.com/AminBlg/SimpleEnglish), which is the
one third-party work adacovex vendors into its own tree. The vendored copy sits
at `skills/simple-english/`, so that adacovex dogfooding and CI need no network
access to apply the rules. It holds `SKILL.md` plus `references/word-swaps.md`,
`references/use-cases.md`, and `references/checklist.md`.

The licence is MIT, and the full terms are in
[the third-party notices](THIRD_PARTY_NOTICES.md). The vendored copy carries two
project overrides, and both are stated in `AGENTS.md` under Technical writing.
British English spelling replaces the American spelling that rule 1.14 names,
and a paragraph holds at most four sentences, not the six that rule 6.6 names.
The controlled list of Technical Names that the standard requires sits in
[the STE100 technical names](contributing/ste100/index.md), and a writer adds a
new name to that list before using it.

The skill governs prose: user documentation, Ada docstrings, and the changelogs.
The rules it enforces in practice are short sentences, active voice, one
instruction per sentence, one word with one meaning, consistent terminology,
and no hedging.

## Third-party components

The [docs/THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) file contains the full licence details and component tables.

## Performance engineering

The benchmark and profiling work in [docs/contributing/perf/index.md](contributing/perf/index.md)
uses [perf](https://perfwiki.github.io/main/), [strace](https://strace.io/), and
[hyperfine](https://github.com/sharkdp/hyperfine). The incremental-caching design
(drawn from the [Ada Language Server](https://github.com/AdaCore/ada_language_server)
and [tree-sitter](https://github.com/tree-sitter/tree-sitter), and the index
dirty-tracking of [git](https://git-scm.com/)) is credited in full in the
[Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Docs generation and hosting

The manual at `docs/` is built with [Sphinx](https://www.sphinx-doc.org/) (using the [Furo](https://github.com/pradyunsg/furo) theme and the [MyST](https://myst-parser.readthedocs.io/) Markdown parser) and the online copy is hosted by [Read the Docs](https://readthedocs.org/). Sphinx, Furo and MyST are credited in full in the [Third-Party Notices](THIRD_PARTY_NOTICES.md). The pages are offered under the adacovex licence.

The manual states what the online site records about a reader in [site transparency](site-transparency.md). The hosting provider counts page views in aggregate with its own analytics, and the project adds no tracker of its own.
