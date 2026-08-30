# Compliance Outputs

This directory holds the compliance documents that an adacovex run
generates for its target.

## Files

- [VERIFICATION.md](VERIFICATION.md) -- the verification results report
  for the target: proof level, test status, and DAL/ASIL/class outcome.
- [TRACE.md](TRACE.md) -- the traceability matrix between source,
  requirements, and compliance evidence.
- [HLR.md](HLR.md) -- the High-Level Requirements index.
- [LLR.md](LLR.md) -- the Low-Level Requirements mapping.

## How they are produced

The Markdown renderer writes these files when the assessment runs
(`--emit-markdown=PATH`).  They are generated per target.  The full file
formats are documented in [Target projects](../usage/target-projects.md) and
[CLI reference](../usage/cli-reference.md).

The rendered text uses British English and ASD-STE100 Simplified Technical
English.  Technical terms follow the [STE100 Technical Names
dictionary](../contributing/ste100-technical-names.md).  Audit the generated prose
against the dictionary before you use a new word in these reports.