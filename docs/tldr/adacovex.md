# adacovex
> Coverage, proof, and compliance assessment tool for Ada and SPARK projects.
> More information: <https://github.com/bladeacer/adacovex>.

- Assess the current project and print the report:
`adacovex`

- Assess a project at another path:
`adacovex --target {{path/to/project}}`

- Assess against a compliance standard and tier:
`adacovex --standard {{dal-c}}`

- Run SPARK proofs, then assess the result:
`adacovex prove`

- Serve the results as a web dashboard:
`adacovex --serve`

- Check SPARK proof coverage:
`adacovex spark-coverage`

- Install the man page into the local man database:
`adacovex man`

- Generate an SBOM:
`adacovex sbom`
