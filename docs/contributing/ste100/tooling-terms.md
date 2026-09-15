# STE100 Technical Names: tooling and workflow terms

The **tooling and workflow** terms of the [STE100 Technical Names]
(index.md) dictionary.  These terms name the commands,
flags, artefacts, and quality gates of the adacovex tool.

## Technical Name: Software Bill of Materials (SBOM)
- **Part of Speech:** Noun
- **Definition:** A formal list of the components that make up a software
  product, with their versions and licences.
- **Approved Form:** Software Bill of Materials (singular), SBOM
  (abbreviation)
- **Do Not Use:** Component list, Dependency list, Package list
- **Correct Example:** *The **SBOM** lists every component with its licence.*
- **Incorrect Example:** *The component list shows every package with its licence.*

## Technical Name: Snapshot
- **Part of Speech:** Noun
- **Definition:** A copy of a repository at a specific revision, taken for a
  differential assessment.
- **Approved Form:** Snapshot (singular), Snapshots (plural)
- **Do Not Use:** Image, Clone (when the differential snapshot is meant)
- **Correct Example:** *The tool takes a **snapshot** of the base revision.*
- **Incorrect Example:** *The tool takes a clone of the base revision.*

## Technical Name: Toolchain
- **Part of Speech:** Noun
- **Definition:** The set of compiler and proof tools that build and verify
  the Ada sources. For adacovex this is GNAT, gnatprove, and their solvers.
- **Approved Form:** Toolchain (singular), Toolchains (plural)
- **Do Not Use:** Tool set, Suite, Environment
- **Correct Example:** *The **toolchain** bin directory is added to PATH.*
- **Incorrect Example:** *The tool set bin directory is added to PATH.*

## Technical Name: Exit Code
- **Part of Speech:** Noun
- **Definition:** The integer that a process returns to its caller when it
  finishes. Zero means success. Non-zero means failure.
- **Approved Form:** Exit Code (singular), Exit Codes (plural)
- **Do Not Use:** Return code, Status code, Return value (when the code is
  meant)
- **Correct Example:** *The command returns **exit code** 1 when a gate fails.*
- **Incorrect Example:** *The command returns return code 1 when a gate fails.*

## Technical Name: Subcommand
- **Part of Speech:** Noun
- **Definition:** A named verb of the adacovex command line. Examples are
  `prove`, `status`, `sbom`, `man`, and `completion`.
- **Approved Form:** Subcommand (singular), Subcommands (plural)
- **Do Not Use:** Command (when the verb is meant), Mode, Verb
- **Correct Example:** *The `prove` **subcommand** runs gnatprove.*
- **Incorrect Example:** *The prove mode runs gnatprove.*

## Technical Name: Flag
- **Part of Speech:** Noun
- **Definition:** A named option of the command line, in the form `--name`.
  For example, `--target`.
- **Approved Form:** Flag (singular), Flags (plural)
- **Do Not Use:** Option, Switch, Parameter (when the CLI flag is meant)
- **Correct Example:** *The `--target` **flag** points at the project.*
- **Incorrect Example:** *The `--target` option points at the project.*

## Technical Name: Badge
- **Part of Speech:** Noun
- **Definition:** A small SVG image that shows one metric, for example the
  SPARK level or the test result.
- **Approved Form:** Badge (singular), Badges (plural)
- **Do Not Use:** Icon, Image, Shield
- **Correct Example:** *The **badge** shows the DO-178C compliance status.*
- **Incorrect Example:** *The icon shows the DO-178C compliance status.*

## Technical Name: Dashboard
- **Part of Speech:** Noun
- **Definition:** The web page that shows the assessment results of a target
  project. The `--serve` flag starts the dashboard.
- **Approved Form:** Dashboard (singular), Dashboards (plural)
- **Do Not Use:** Report page, Control panel, UI page
- **Correct Example:** *The **dashboard** shows the SPARK level and the test results.*
- **Incorrect Example:** *The report page shows the SPARK level and the test results.*

## Technical Name: Machine-Integer Type
- **Part of Speech:** Noun
- **Definition:** A bounded integer type that models a machine integer of a
  target word size. Examples are `IR_Int32` and `IR_UInt64`.
- **Approved Form:** Machine-Integer Type (singular), Machine-Integer Types
  (plural)
- **Do Not Use:** Integer type (when the bounded IR type is meant), C type
- **Correct Example:** *The **machine-integer type** `IR_Int32` cannot overflow.*
- **Incorrect Example:** *The C type `IR_Int32` cannot overflow.*

## Technical Name: Docstring
- **Part of Speech:** Noun
- **Definition:** A structured comment that documents a subprogram and counts
  toward docstring coverage. It uses tags such as `@param` and `@return`.
- **Approved Form:** Docstring (singular), Docstrings (plural)
- **Do Not Use:** Comment (when the docstring is meant), Documentation
  comment (after the first use)
- **Correct Example:** *Every subprogram has a **docstring** with a summary.*
- **Incorrect Example:** *Every subprogram has a comment with a summary.*

## Technical Name: Cyclomatic Complexity
- **Part of Speech:** Noun
- **Definition:** A count of the independent paths through a subprogram. The
  complexity gate rejects files and subprograms above the configured limit.
- **Approved Form:** Cyclomatic Complexity (no plural)
- **Do Not Use:** Complexity (when the metric is meant), Branch count
- **Correct Example:** *The gate fails when the **cyclomatic complexity** of a subprogram is too high.*
- **Incorrect Example:** *The gate fails when the branch count of a subprogram is too high.*

## Technical Name: LOC
- **Part of Speech:** Noun
- **Definition:** Lines of code. The complexity gate caps the LOC of a file
  and the share of the codebase that a file may hold.
- **Approved Form:** LOC (no plural)
- **Do Not Use:** Lines (ambiguous), Source lines (after the first use)
- **Correct Example:** *No file exceeds the **LOC** cap.*
- **Incorrect Example:** *No file exceeds the lines cap.*

## Technical Name: Proof Patch
- **Part of Speech:** Noun
- **Definition:** A patch file under `.adacovex/patches` that adds SPARK
  contracts to vendored code. The prove subcommand merges the patch into a
  proof tree copy and proves the vendored code against it.
- **Approved Form:** Proof Patch (singular), Proof Patches (plural)
- **Do Not Use:** Contract patch, SPARK patch, Merge file
- **Correct Example:** *A **proof patch** adds contracts to the vendored spec.*
- **Incorrect Example:** *A contract patch adds contracts to the vendored spec.*

## Technical Name: Version Control System (VCS)
- **Part of Speech:** Noun
- **Definition:** A system that records revisions of source files. The
  differential modes snapshot a base revision from the VCS of the target.
- **Approved Form:** Version Control System (singular), VCS (abbreviation)
- **Do Not Use:** Source control (after the first use), Repository system
- **Correct Example:** *The **VCS** of the target must be git or another supported system.*
- **Incorrect Example:** *The repository system of the target must be git or another supported system.*

## Technical Name: Differential Assessment
- **Part of Speech:** Noun
- **Definition:** A comparison of the current tree against a base revision.
  The `--compare-base` and `--coverage-delta` flags run a differential
  assessment.
- **Approved Form:** Differential Assessment (singular), Differential
  Assessments (plural)
- **Do Not Use:** Diff run, Comparison run, Delta check
- **Correct Example:** *The **differential assessment** compares the tree against the base revision.*
- **Incorrect Example:** *The diff run compares the tree against the base revision.*

## Technical Name: Result Cache
- **Part of Speech:** Noun
- **Definition:** The on-disk cache that reuses a prior proof or scan result
  when the inputs are unchanged. The cache keys on a content hash of the
  inputs.
- **Approved Form:** Result Cache (singular), Result Caches (plural)
- **Do Not Use:** Cache (when the result cache is meant), Artifact store
- **Correct Example:** *The **result cache** serves the proof when the inputs are unchanged.*
- **Incorrect Example:** *The artifact store serves the proof when the inputs are unchanged.*

## Technical Name: Stat-Stamp Index
- **Part of Speech:** Noun
- **Definition:** The persistent on-disk index of file size, modification
  time, and content hash. adacovex consults it to skip re-hashing a file that
  did not change since the last run.
- **Approved Form:** Stat-Stamp Index (singular), Stat-Stamp Indexes (plural)
- **Do Not Use:** Hash index, File index, Stamp store
- **Correct Example:** *The **stat-stamp index** serves the digest without re-reading the file.*
- **Incorrect Example:** *The hash index serves the digest without re-reading the file.*

## Technical Name: Safety Class
- **Part of Speech:** Noun
- **Definition:** One of the IEC 62304 classes (A, B, or C) that classify the
  risk of a medical-device software item. Class C is the highest risk.
- **Approved Form:** Safety Class (singular), Safety Classes (plural)
- **Do Not Use:** Integrity class, Class (when the safety class is meant)
- **Correct Example:** *The target achieves **safety Class A** under IEC 62304.*
- **Incorrect Example:** *The target achieves integrity class A under IEC 62304.*

## Technical Name: Man Page
- **Part of Speech:** Noun
- **Definition:** The manual page for adacovex. The `man` subcommand installs
  the page into the local man database and checks it with `man --check`.
- **Approved Form:** Man Page (singular), Man Pages (plural)
- **Do Not Use:** Manual page (after the first use), Help page
- **Correct Example:** *The **man page** embeds the binary version.*
- **Incorrect Example:** *The help page embeds the binary version.*

## Technical Name: DO-178C
- **Part of Speech:** Noun
- **Definition:** The avionics software standard that defines the DAL levels
  A to E. adacovex assesses DO-178C compliance.
- **Approved Form:** DO-178C (exact form)
- **Do Not Use:** The avionics standard (after the first use), RTCA standard
- **Correct Example:** *adacovex assesses compliance with **DO-178C** at every DAL level.*
- **Incorrect Example:** *adacovex assesses compliance with the RTCA standard at every DAL level.*

## Technical Name: ISO 26262
- **Part of Speech:** Noun
- **Definition:** The automotive functional-safety standard that defines the
  ASIL levels. adacovex assesses ISO 26262 compliance.
- **Approved Form:** ISO 26262 (exact form)
- **Do Not Use:** The automotive standard (after the first use)
- **Correct Example:** *The target achieves **ASIL B** under ISO 26262.*
- **Incorrect Example:** *The target achieves ASIL B under the automotive standard.*

## Technical Name: IEC 62304
- **Part of Speech:** Noun
- **Definition:** The medical-device software standard that defines the
  safety classes A to C. adacovex assesses IEC 62304 compliance.
- **Approved Form:** IEC 62304 (exact form)
- **Do Not Use:** The medical standard (after the first use)
- **Correct Example:** *The target achieves **safety Class A** under IEC 62304.*
- **Incorrect Example:** *The target achieves safety Class A under the medical standard.*
