# Credits

bladeacer develops and maintains adacovex.

## Third-party components

The [docs/THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) file contains the full licence details and component tables.

## Technical writing guidance

User documentation follows ASD-STE100 Simplified Technical English. The [SimpleEnglish skill](https://github.com/AminBlg/SimpleEnglish) guides this work.

## Performance engineering

The benchmark and profiling work in [docs/contributing/perf.md](contributing/perf.md)
uses [perf](https://perfwiki.github.io/main/), [strace](https://strace.io/), and
[hyperfine](https://github.com/sharkdp/hyperfine). The incremental-caching design
(drawn from the [Ada Language Server](https://github.com/AdaCore/ada_language_server)
and [tree-sitter](https://github.com/tree-sitter/tree-sitter), and the index
dirty-tracking of [git](https://git-scm.com/)) is credited in full in the
[Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Docs generation and hosting

The manual at `docs/` is built with [Sphinx](https://www.sphinx-doc.org/) (using the [Furo](https://github.com/pradyunsg/furo) theme and the [MyST](https://myst-parser.readthedocs.io/) Markdown parser) and the online copy is hosted by [Read the Docs](https://readthedocs.org/). Sphinx, Furo and MyST are credited in full in the [Third-Party Notices](THIRD_PARTY_NOTICES.md). The pages are offered under the adacovex licence.