# STE100 Technical Names: tools and files

The **tools and files** half of the **Code Identifier Names** category of the
[STE100 Technical Names](ste100-technical-names.md) dictionary.  These terms
name the exact tool, command, and file identifiers that appear in the
documentation.  The report and concept identifiers are on
[reports and concepts](ste100-concepts.md).

## Technical Name: adacovex
- **Part of Speech:** Noun
- **Definition:** The name of this tool. Use the exact lower-case spelling.
- **Approved Form:** adacovex
- **Do Not Use:** Ada Covex, Adacovex, the tool (when the name is meant)
- **Correct Example:** *Run **adacovex** with the `prove` subcommand.*
- **Incorrect Example:** *Run Adacovex with the prove subcommand.*

## Technical Name: covex
- **Part of Speech:** Noun
- **Definition:** The alias name for the adacovex binary, used in Alire
  crates. The release bundle ships both names.
- **Approved Form:** covex
- **Do Not Use:** Covex, the binary (when the name is meant)
- **Correct Example:** *The bundle contains **covex** as an alias for adacovex.*
- **Incorrect Example:** *The bundle contains Covex as an alias for adacovex.*

## Technical Name: Alire
- **Part of Speech:** Noun
- **Definition:** The Ada package manager and its ecosystem. The `alr`
  command is its command-line tool.
- **Approved Form:** Alire
- **Do Not Use:** Package manager (when Alire is meant), Ada package
  manager (after the first use)
- **Correct Example:** ***Alire** resolves the gnatprove dependency.*
- **Incorrect Example:** *The package manager resolves the gnatprove dependency.*

## Technical Name: alr
- **Part of Speech:** Noun
- **Definition:** The command-line tool of Alire. Use the exact lower-case
  spelling when the command is meant.
- **Approved Form:** alr
- **Do Not Use:** Alire (when the command is meant), the installer
- **Correct Example:** *Run `alr build` to build the project.*
- **Incorrect Example:** *Run Alire build to build the project.*

## Technical Name: GNAT
- **Part of Speech:** Noun
- **Definition:** The GNU Ada compiler suite. adacovex uses only the GNAT
  runtime.
- **Approved Form:** GNAT (all capitals)
- **Do Not Use:** Compiler (when GNAT is meant), Gnat, gnat
- **Correct Example:** *The binary depends only on the **GNAT** runtime.*
- **Incorrect Example:** *The binary depends only on the Gnat runtime.*

## Technical Name: gnatprove
- **Part of Speech:** Noun
- **Definition:** The SPARK proof tool. The command is `gnatprove`. The
  product name is GNATprove.
- **Approved Form:** gnatprove (for the command), GNATprove (for the
  product)
- **Do Not Use:** Prover (when gnatprove is meant), Proof tool (after the
  first use)
- **Correct Example:** *The `prove` subcommand runs **gnatprove** on the target.*
- **Incorrect Example:** *The prove subcommand runs the prover on the target.*

## Technical Name: gnatdoc
- **Part of Speech:** Noun
- **Definition:** The Ada documentation generator that produces the API
  reference from source docstrings.
- **Approved Form:** gnatdoc (exact lower-case)
- **Do Not Use:** Doc generator, Documentation tool (when gnatdoc is meant)
- **Correct Example:** *`make doc` runs **gnatdoc** on the Ada sources.*
- **Incorrect Example:** *`make doc` runs the doc generator on the Ada sources.*

## Technical Name: Manifest
- **Part of Speech:** Noun
- **Definition:** The Alire manifest file of a crate. The files are
  `alire.toml` and `alire-dev.toml`.
- **Approved Form:** Manifest (singular), Manifests (plural)
- **Do Not Use:** Configuration file, Metadata file, TOML file (when the
  manifest is meant)
- **Correct Example:** *The **manifest** declares the gnatprove dependency.*
- **Incorrect Example:** *The configuration file declares the gnatprove dependency.*

## Technical Name: alire.lock
- **Part of Speech:** Noun
- **Definition:** The solved dependency list that Alire writes. It records
  the exact versions of every resolved crate.
- **Approved Form:** alire.lock (exact file name)
- **Do Not Use:** Lock file (when alire.lock is meant), Dependency file
- **Correct Example:** *The parser reads **alire.lock** to build the dependency graph.*
- **Incorrect Example:** *The parser reads the lock file to build the dependency graph.*

## Technical Name: GNAT Project File (.gpr)
- **Part of Speech:** Noun
- **Definition:** A build description file with the `.gpr` extension. The
  proof run targets the root `.gpr` file of the target project.
- **Approved Form:** GNAT Project File (singular), .gpr (abbreviation)
- **Do Not Use:** Project file (when the .gpr file is meant), Build file
- **Correct Example:** *gnatprove runs against the root **.gpr** file.*
- **Incorrect Example:** *gnatprove runs against the root build file.*

## Technical Name: gnatprove.out
- **Part of Speech:** Noun
- **Definition:** The output file that gnatprove writes. It contains the
  proof summary and the VC counts. The assessment pipeline parses it.
- **Approved Form:** gnatprove.out (exact file name)
- **Do Not Use:** Proof output (when the file is meant), The out file
- **Correct Example:** *The parser reads `obj/gnatprove/gnatprove.out`.*
- **Incorrect Example:** *The parser reads the proof output file.*

## Technical Name: AUnit
- **Part of Speech:** Noun
- **Definition:** The Ada unit-test framework. The test-result parser reads
  AUnit output.
- **Approved Form:** AUnit
- **Do Not Use:** Test framework (when AUnit is meant), Test suite (when the
  framework is meant)
- **Correct Example:** *The native tests run under **AUnit**.*
- **Incorrect Example:** *The native tests run under the test framework.*

## Technical Name: SPARK_Mode
- **Part of Speech:** Noun
- **Definition:** The Ada pragma or aspect that enables SPARK analysis for a
  unit. Use the exact spelling with the underscore.
- **Approved Form:** SPARK_Mode (exact spelling)
- **Do Not Use:** SPARK mode, Spark_Mode, Spark mode
- **Correct Example:** *The package declares `SPARK_Mode => On`.*
- **Incorrect Example:** *The package declares SPARK mode on.*

## Technical Name: HLR Tag
- **Part of Speech:** Noun
- **Definition:** A source comment of the form `-- HLR-XXXX` that traces a
  source element to a high-level requirement.
- **Approved Form:** HLR Tag (singular), HLR Tags (plural), HLR-XXXX (the
  tag form)
- **Do Not Use:** Tag (when the HLR tag is meant), Annotation
- **Correct Example:** *The subprogram carries the **HLR tag** `-- HLR-ARCH`.*
- **Incorrect Example:** *The subprogram carries the annotation `-- HLR-ARCH`.*

## Technical Name: CycloneDX
- **Part of Speech:** Noun
- **Definition:** The SBOM exchange schema that adacovex uses for the
  CycloneDX 1.5 JSON SBOM format.
- **Approved Form:** CycloneDX (exact form)
- **Do Not Use:** Cyclonedx, Cyclone DX, SBOM format (when CycloneDX is
  meant)
- **Correct Example:** *The `sbom` subcommand emits **CycloneDX** 1.5 JSON.*
- **Incorrect Example:** *The sbom subcommand emits Cyclone DX 1.5 JSON.*

## Technical Name: SPDX
- **Part of Speech:** Noun
- **Definition:** The software package data exchange schema that adacovex
  uses for the SPDX 2.3 JSON SBOM format.
- **Approved Form:** SPDX (exact capitals)
- **Do Not Use:** Spdx, spdx, License schema (when SPDX is meant)
- **Correct Example:** *The `sbom` subcommand also emits **SPDX** 2.3 JSON.*
- **Incorrect Example:** *The sbom subcommand also emits Spdx 2.3 JSON.*

## Technical Name: ANSI
- **Part of Speech:** Modifier
- **Definition:** The escape-code standard used for colour output in a
  terminal. Always use it with the noun codes.
- **Approved Form:** ANSI (as modifier, for example ANSI escape codes)
- **Do Not Use:** Terminal codes, Colour codes
- **Correct Example:** *The report uses **ANSI** escape codes for colour.*
- **Incorrect Example:** *The report uses terminal codes for colour.*

## Technical Name: NO_COLOR
- **Part of Speech:** Noun
- **Definition:** The environment variable that disables colour output. When
  it is set, the ANSI report prints without colour.
- **Approved Form:** NO_COLOR (exact capitals)
- **Do Not Use:** No color variable, The colour switch (when the variable is
  meant)
- **Correct Example:** *The report honours the **NO_COLOR** environment variable.*
- **Incorrect Example:** *The report honours the No color environment variable.*

## Technical Name: gnatformat
- **Part of Speech:** Noun
- **Definition:** The GNAT source formatter. The `make fmt` target runs
  gnatformat on the Ada sources.
- **Approved Form:** gnatformat (exact lower-case)
- **Do Not Use:** Formatter (when gnatformat is meant), Gnat format
- **Correct Example:** *`make fmt` runs **gnatformat** on the sources.*
- **Incorrect Example:** *`make fmt` runs the formatter on the sources.*
