# Lockfile fixtures

Each directory holds one lockfile from a real ecosystem, with the versions
the ecosystem's resolver writes. The SBOM test suite copies a lockfile into a
temporary project root and checks the transitive components the graph
resolves from it: name, version, PURL type, language, and scope. The fixtures
are data, not program source, so the architecture tree skips them.
