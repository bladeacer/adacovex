# Adacovex.Opt_Outs

Top-of-file opt-out annotation detection for per-file gate exclusions.
A source, documentation, or data file can carry a marker directive in
its leading comment block to opt out of one adacovex analysis gate.
The directive is a marker token on a comment line near the top of the
file (the first non-comment, non-blank line ends the header block, so
prose or code further down never counts).  The comment syntax follows
the file's own language:

  --  no-covex-complexity-scan    (Ada: --, YAML/Python/Shell: #,
--  no-covex-docstrings          C-family: //, RST: .. , and so on)
--  no-covex-spark-proof         (opt the file out of the proof run)
<!-- no-covex-analysis -->       (Markdown/HTML comment also counts)

The recognised markers are:

  no-covex-complexity-scan  opt the file out of the complexity/LOC gate
no-covex-docstrings       opt the file out of docstring coverage
no-covex-spark-proof      opt the file out of the SPARK proof run
no-covex-analysis         opt the file out of all three gates

Matching is case-insensitive and independent of the comment prefix, so
the same marker text works in Ada, Markdown, Python, Rust, and every
other scanned language.
HLR-SCAN: Per-file opt-out annotations

> **Note:** All items in this package are public.

## Types

### type Gate

```ada
type Gate is (Complexity_Scan, Docstrings, SPARK_Proof);
```

## Functions

### function File_Opts_Out (Path : Standard.String; G : Adacovex.Opt_Outs.Gate) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `G` | Analysis gate to test for an opt-out marker. |
| `Path` | File path to inspect. |

**Returns:** True when a matching marker appears in the file header.
