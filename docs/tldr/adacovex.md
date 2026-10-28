# adacovex
> Zero-dependency Ada/SPARK formal verification and compliance toolkit for coverage analysis, proof verification, test-result parsing, multi-standard safety-compliance assessment (DO-178C / ISO 26262 / IEC 62304), and interactive dashboards.
> More information: <https://github.com/bladeacer/adacovex>.

- Assess the current project:
`adacovex`

- Assess a project at another path:
`adacovex --target={{path/to/project}}`

- Assess against a compliance standard and tier:
`adacovex --standard {{dal-c}}`

- Run SPARK proofs, then assess the result:
`adacovex prove`

- Serve the results as a web dashboard:
`adacovex --serve`

- Print SPARK proof-coverage metrics and CI gates:
`adacovex spark-coverage`

- Install the man page:
`adacovex man`

- Install the built-in cheat sheet for a tldr client:
`adacovex tldr`

- Print shell auto-completion scripts:
`adacovex completion bash`

- Generate an SBOM:
`adacovex sbom`

- Print the version and exit:
`adacovex --version`
