# SBOM ecosystem fixtures

Each directory under `ecosystems/` is a mini project for one ecosystem
the SBOM parser reads. The set is the union of adacovex's own
ecosystems and the languages syft catalogues from a source tree, plus
Ada:

npm, cargo, golang, pypi (pyproject, setup.cfg, requirements),
composer, cpan, gem (Gemfile, gemspec), maven (pom, Gradle Groovy and
Kotlin DSL), swift, cocoapods, pub, nuget, hex (Elixir, Erlang), cran,
conan (python and text), luarocks, opam, hackage, and Ada.

`src/tests/adacovex_sbom_tests.adb` copies each project into a temporary
vendor tree and asserts the parsed name, version, licence, PURL type,
and language, then reads the five projects that declare root
dependencies as root projects and asserts their base and dev scopes.
The fixtures are committed rather than written inline, so a new
ecosystem row needs a real project a reader can open.
