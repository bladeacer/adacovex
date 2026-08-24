# STE100 Technical Names for adacovex

ASD-STE100 Simplified Technical English (Section 1, "Words") defines a
controlled vocabulary. Most words in that vocabulary are standard STE words.
Some concepts have no accurate standard STE word. For those concepts, the
project approves a **Technical Name (TN)**.

A Technical Name is a non-STE word that the project explicitly approves. The
project approves it because no standard STE word describes the concept with
the same precision. A TN has a single mandatory part of speech and a defined
scope. The scope is restricted to the software domain of adacovex.

This page is the controlled list of Technical Names for adacovex. Writers of
user documentation, API documentation, docstrings, and changelogs must use
these terms as defined here. If you need a term that is not in this list,
add it to the list first, then use it.

## Categories for Ada Technical Names

Group the Technical Names by their structural role in the software domain.

- **Hardware and System Entities.** Physical components, buses, or
  microarchitectures that the Ada code interacts with. For example, CPU core.
- **Ada Language Constructs.** Specific language features that generic
  English words cannot replace without losing technical precision. For
  example, pragma, discriminant, rendezvous, task.
- **Domain and Mathematical Terms.** Algorithmic, mathematical, or
  mission-specific logic terms. For example, telemetry, checksum,
  quaternion.
- **Code Identifier Names.** Exact package, type, subtype, subprogram, and
  variable names as declared in the source code. For example,
  `System.Storage_Elements`, `Buffer_Size`. This category also covers exact
  file names, tool commands, and flag names that appear in documentation.

## Required data fields for each entry

ASD-STE100 requires strict controls over how approved words are documented.
Every Technical Name in this dictionary has all five fields:

| Field | Description | Example |
| --- | --- | --- |
| **Approved Word (TN)** | The exact word or identifier. | **Pragma** |
| **Part of Speech** | STE permits a word as only *one* part of speech (Noun, Verb, Modifier). | Noun |
| **Approved Meaning / Definition** | Clear, unambiguous definition restricted to the adacovex domain. | A compiler directive in the Ada programming language. |
| **Non-Approved Alternatives** | Terms that authors must NOT use instead of this TN. | *Compiler directive*, *Annotation* |
| **Example Sentence** | A compliant STE sentence demonstrating usage. | *Add the **pragma** to the top of the package specification.* |

## Key rules for Ada Technical Names

- **Nouns stay nouns.** Technical Names are almost always approved as Nouns
  or Modifiers. Never approve a code action as a verb if a standard STE verb
  exists. For example, use the approved verb *Calculate* instead of creating
  a TN verb *Compute*.
- **Exact case matching.** Treat Ada identifiers (`Pascal_Case` or
  `UPPER_CASE`) as literal Technical Names. Use the exact casing in
  documentation. This rule distinguishes language concepts from code
  entities.
- **No synonyms.** If the project approves *Task* as a TN for an Ada
  concurrent execution unit, do not use words like *Thread*, *Process*, or
  *Job* for that concept.
- **One part of speech per word.** A TN is a Noun or a Modifier, never both.
  When you need the action, use the standard STE verb that matches the noun
  form.

## Standard entry template

```markdown
### Technical Name: Task
- **Part of Speech:** Noun
- **Category:** Ada Language Construct
- **Definition:** A standalone unit of concurrent execution in Ada.
- **Approved Form:** Task (singular), Tasks (plural)
- **Do Not Use:** Thread, Process, Job, Execution Unit
- **Correct Example:** *The main **task** waits for the sensor **task** to finish.*
- **Incorrect Example:** *The main process waits for the sensor thread to complete.*
```

## Dictionary

### Category: Ada Language Constructs

#### Technical Name: Package
- **Part of Speech:** Noun
- **Definition:** A named collection of related declarations in Ada. A
  package has a visible specification and a private body.
- **Approved Form:** Package (singular), Packages (plural)
- **Do Not Use:** Module, Library unit, Component
- **Correct Example:** *A **package** groups the related subprograms.*
- **Incorrect Example:** *A module groups the related subprograms.*

#### Technical Name: Package Body
- **Part of Speech:** Noun
- **Definition:** The implementation part of a package. It contains the
  bodies of the subprograms that the package specification declares.
- **Approved Form:** Package Body (singular), Package Bodies (plural)
- **Do Not Use:** Implementation file, Source file (when ambiguous)
- **Correct Example:** *The **package body** implements the declared subprograms.*
- **Incorrect Example:** *The implementation file implements the declared subprograms.*

#### Technical Name: Specification
- **Part of Speech:** Noun
- **Definition:** The visible declaration part of a package or subprogram.
  In Ada, the specification is the `.ads` file of a package.
- **Approved Form:** Specification (singular), Specifications (plural)
- **Do Not Use:** Header, Interface file, Definition
- **Correct Example:** *The package **specification** declares the public subprograms.*
- **Incorrect Example:** *The package header declares the public subprograms.*

#### Technical Name: Subprogram
- **Part of Speech:** Noun
- **Definition:** A named unit of executable code in Ada. A subprogram is
  either a procedure or a function.
- **Approved Form:** Subprogram (singular), Subprograms (plural)
- **Do Not Use:** Routine, Method, Function (for the general concept)
- **Correct Example:** *Every **subprogram** in the source tree has a docstring.*
- **Incorrect Example:** *Every routine in the source tree has a docstring.*

#### Technical Name: Procedure
- **Part of Speech:** Noun
- **Definition:** A subprogram that performs an action and does not return a
  value.
- **Approved Form:** Procedure (singular), Procedures (plural)
- **Do Not Use:** Routine, Operation
- **Correct Example:** *The **procedure** writes the report to a file.*
- **Incorrect Example:** *The routine writes the report to a file.*

#### Technical Name: Function
- **Part of Speech:** Noun
- **Definition:** A subprogram that returns a value.
- **Approved Form:** Function (singular), Functions (plural)
- **Do Not Use:** Method, Callable
- **Correct Example:** *The **function** returns the number of cores.*
- **Incorrect Example:** *The method returns the number of cores.*

#### Technical Name: Task
- **Part of Speech:** Noun
- **Definition:** A unit of concurrent execution in the Ada language.
- **Approved Form:** Task (singular), Tasks (plural)
- **Do Not Use:** Thread, Process, Job, Execution Unit
- **Correct Example:** *The HTTP server runs a pool of four **tasks**.*
- **Incorrect Example:** *The HTTP server runs a pool of four threads.*

#### Technical Name: Pragma
- **Part of Speech:** Noun
- **Definition:** A compiler directive in the Ada programming language.
- **Approved Form:** Pragma (singular), Pragmas (plural)
- **Do Not Use:** Compiler directive, Annotation, Attribute
- **Correct Example:** *The **pragma** `SPARK_Mode` enables SPARK analysis.*
- **Incorrect Example:** *The compiler directive `SPARK_Mode` enables SPARK analysis.*

#### Technical Name: Aspect
- **Part of Speech:** Noun
- **Definition:** A declaration-level property in Ada 2012 that attaches
  contracts to a declaration. Examples are `Pre`, `Post`, and `Global`.
- **Approved Form:** Aspect (singular), Aspects (plural)
- **Do Not Use:** Property, Annotation, Attribute
- **Correct Example:** *The **aspect** `Pre` states the precondition.*
- **Incorrect Example:** *The property `Pre` states the precondition.*

#### Technical Name: Contract
- **Part of Speech:** Noun
- **Definition:** The set of preconditions, postconditions, and global
  dependencies that describe subprogram behaviour for the proof tool.
- **Approved Form:** Contract (singular), Contracts (plural)
- **Do Not Use:** Agreement, Promise, Guarantee
- **Correct Example:** *gnatprove proves the **contracts** of every subprogram.*
- **Incorrect Example:** *gnatprove proves the guarantees of every subprogram.*

#### Technical Name: Generic
- **Part of Speech:** Modifier
- **Definition:** A unit that is parameterised and that a caller instantiates
  with actual parameters. Used with the nouns package, subprogram, or
  procedure.
- **Approved Form:** Generic (as modifier only)
- **Do Not Use:** Template, Parameterised unit (as a noun)
- **Correct Example:** *A **generic** package instantiates a vector type.*
- **Incorrect Example:** *A template package instantiates a vector type.*

#### Technical Name: Type
- **Part of Speech:** Noun
- **Definition:** A named set of values and the operations on those values in
  Ada.
- **Approved Form:** Type (singular), Types (plural)
- **Do Not Use:** Datatype, Data type (when the Ada type is meant)
- **Correct Example:** *The **type** `IR_Int32` is a bounded integer type.*
- **Incorrect Example:** *The datatype `IR_Int32` is a bounded integer type.*

#### Technical Name: Object
- **Part of Speech:** Noun
- **Definition:** A variable or constant that has a type in Ada.
- **Approved Form:** Object (singular), Objects (plural)
- **Do Not Use:** Instance (when the Ada object is meant), Variable (when a
  constant is also possible)
- **Correct Example:** *The proof checks that every **object** is initialised.*
- **Incorrect Example:** *The proof checks that every instance is initialised.*

#### Technical Name: SPARK
- **Part of Speech:** Noun
- **Definition:** The formally analysable subset of Ada that the gnatprove
  proof tool verifies. adacovex targets the Platinum SPARK level.
- **Approved Form:** SPARK (exact capitals)
- **Do Not Use:** Spark, spark, Ada subset (when SPARK is meant)
- **Correct Example:** *The source is written in **SPARK** and proved with gnatprove.*
- **Incorrect Example:** *The source is written in Spark and proved with gnatprove.*

### Category: Domain and Mathematical Terms

#### Technical Name: Verification Condition (VC)
- **Part of Speech:** Noun
- **Definition:** A logical statement that a proof tool must prove. gnatprove
  reports VCs per check category, for example flow, run-time, and assertion.
- **Approved Form:** Verification Condition (singular), Verification
  Conditions (plural), VC (singular), VCs (plural)
- **Do Not Use:** Proof goal, Proof obligation, Test case
- **Correct Example:** *The proof proves all 722 **VCs**.*
- **Incorrect Example:** *The proof proves all 722 proof obligations.*

#### Technical Name: Assertion
- **Part of Speech:** Noun
- **Definition:** A user-written property that must hold at a point in the
  program. In Ada, an assertion is a `pragma Assert`.
- **Approved Form:** Assertion (singular), Assertions (plural)
- **Do Not Use:** Assumption, Check, Statement of truth
- **Correct Example:** *The **assertion** proves that the index is in range.*
- **Incorrect Example:** *The assumption proves that the index is in range.*

#### Technical Name: Proof
- **Part of Speech:** Noun
- **Definition:** A formal demonstration, produced by a proof tool, that a
  property of the program holds.
- **Approved Form:** Proof (singular), Proofs (plural)
- **Do Not Use:** Verification (when the proof result is meant),
  Demonstration
- **Correct Example:** *The **proof** has zero unproved verification conditions.*
- **Incorrect Example:** *The verification has zero unproved verification conditions.*

#### Technical Name: SPARK Level
- **Part of Speech:** Noun
- **Definition:** One of the five SPARK assurance levels: Stone, Bronze,
  Silver, Gold, and Platinum. Each level builds on the previous one.
- **Approved Form:** SPARK Level (singular), SPARK Levels (plural)
- **Do Not Use:** Grade (for the concept), Assurance level (when SPARK is
  meant)
- **Correct Example:** *The target reaches **Platinum**, the highest SPARK level.*
- **Incorrect Example:** *The target reaches Platinum, the highest grade.*

#### Technical Name: Coverage
- **Part of Speech:** Noun
- **Definition:** The percentage of subprograms that have a docstring, out of
  all subprograms in the scanned source tree.
- **Approved Form:** Coverage (no plural)
- **Do Not Use:** Completion rate, Documentation rate, Percentage documented
- **Correct Example:** *The docstring **coverage** is 100 per cent.*
- **Incorrect Example:** *The completion rate is 100 per cent.*

#### Technical Name: Design Assurance Level (DAL)
- **Part of Speech:** Noun
- **Definition:** One of the five DO-178C levels (A to E) that classify the
  severity of a failure condition. DAL A is the most severe.
- **Approved Form:** Design Assurance Level (singular), DAL (abbreviation)
- **Do Not Use:** Safety level, Integrity level
- **Correct Example:** *adacovex assesses compliance at **DAL C** for this target.*
- **Incorrect Example:** *adacovex assesses compliance at safety level C for this target.*

#### Technical Name: ASIL
- **Part of Speech:** Noun
- **Definition:** An Automotive Safety Integrity Level from ISO 26262. The
  levels run from QM to ASIL D. ASIL D is the highest hazard level.
- **Approved Form:** ASIL (no plural)
- **Do Not Use:** Automotive safety level, ASIL level (redundant)
- **Correct Example:** *The target achieves **ASIL B** under ISO 26262.*
- **Incorrect Example:** *The target achieves automotive safety level B under ISO 26262.*

#### Technical Name: High-Level Requirement (HLR)
- **Part of Speech:** Noun
- **Definition:** A requirement that states what the software must do, at the
  system or software level, without implementation detail.
- **Approved Form:** High-Level Requirement (singular), HLR (abbreviation)
- **Do Not Use:** Top-level requirement, System requirement (when the HLR
  index is meant)
- **Correct Example:** *Every **HLR** traces to a source tag.*
- **Incorrect Example:** *Every top-level requirement traces to a source tag.*

#### Technical Name: Low-Level Requirement (LLR)
- **Part of Speech:** Noun
- **Definition:** A requirement that states how the software implements a
  high-level requirement, with implementation detail.
- **Approved Form:** Low-Level Requirement (singular), LLR (abbreviation)
- **Do Not Use:** Implementation requirement, Detail requirement
- **Correct Example:** *The **LLR** describes how the parser implements the HLR.*
- **Incorrect Example:** *The detail requirement describes how the parser implements the HLR.*

#### Technical Name: Traceability
- **Part of Speech:** Noun
- **Definition:** The documented mapping between requirements and the source
  code that implements them.
- **Approved Form:** Traceability (no plural)
- **Do Not Use:** Linkage, Mapping (when the concept of traceability is
  meant)
- **Correct Example:** *The report shows the **traceability** from each HLR to its source tags.*
- **Incorrect Example:** *The report shows the linkage from each HLR to its source tags.*

#### Technical Name: Assessment
- **Part of Speech:** Noun
- **Definition:** The process of evaluating a target project against the
  criteria of a standard or a gate.
- **Approved Form:** Assessment (singular), Assessments (plural)
- **Do Not Use:** Analysis (when the evaluation run is meant), Review
- **Correct Example:** *The **assessment** runs without modifying the target tree.*
- **Incorrect Example:** *The analysis runs without modifying the target tree.*

#### Technical Name: Compliance
- **Part of Speech:** Noun
- **Definition:** Conformance of the target with the criteria of a standard,
  for example DO-178C or ISO 26262.
- **Approved Form:** Compliance (no plural)
- **Do Not Use:** Adherence, Conformance (when the DO-178C result is meant)
- **Correct Example:** *The target shows **compliance** with DO-178C at DAL C.*
- **Incorrect Example:** *The target shows adherence with DO-178C at DAL C.*

#### Technical Name: Software Bill of Materials (SBOM)
- **Part of Speech:** Noun
- **Definition:** A formal list of the components that make up a software
  product, with their versions and licences.
- **Approved Form:** Software Bill of Materials (singular), SBOM
  (abbreviation)
- **Do Not Use:** Component list, Dependency list, Package list
- **Correct Example:** *The **SBOM** lists every component with its licence.*
- **Incorrect Example:** *The component list shows every package with its licence.*

#### Technical Name: Snapshot
- **Part of Speech:** Noun
- **Definition:** A copy of a repository at a specific revision, taken for a
  differential assessment.
- **Approved Form:** Snapshot (singular), Snapshots (plural)
- **Do Not Use:** Image, Clone (when the differential snapshot is meant)
- **Correct Example:** *The tool takes a **snapshot** of the base revision.*
- **Incorrect Example:** *The tool takes a clone of the base revision.*

#### Technical Name: Toolchain
- **Part of Speech:** Noun
- **Definition:** The set of compiler and proof tools that build and verify
  the Ada sources. For adacovex this is GNAT, gnatprove, and their solvers.
- **Approved Form:** Toolchain (singular), Toolchains (plural)
- **Do Not Use:** Tool set, Suite, Environment
- **Correct Example:** *The **toolchain** bin directory is added to PATH.*
- **Incorrect Example:** *The tool set bin directory is added to PATH.*

#### Technical Name: Exit Code
- **Part of Speech:** Noun
- **Definition:** The integer that a process returns to its caller when it
  finishes. Zero means success. Non-zero means failure.
- **Approved Form:** Exit Code (singular), Exit Codes (plural)
- **Do Not Use:** Return code, Status code, Return value (when the code is
  meant)
- **Correct Example:** *The command returns **exit code** 1 when a gate fails.*
- **Incorrect Example:** *The command returns return code 1 when a gate fails.*

#### Technical Name: Subcommand
- **Part of Speech:** Noun
- **Definition:** A named verb of the adacovex command line. Examples are
  `prove`, `status`, `sbom`, `man`, and `completion`.
- **Approved Form:** Subcommand (singular), Subcommands (plural)
- **Do Not Use:** Command (when the verb is meant), Mode, Verb
- **Correct Example:** *The `prove` **subcommand** runs gnatprove.*
- **Incorrect Example:** *The prove mode runs gnatprove.*

#### Technical Name: Flag
- **Part of Speech:** Noun
- **Definition:** A named option of the command line, in the form `--name`.
  For example, `--target`.
- **Approved Form:** Flag (singular), Flags (plural)
- **Do Not Use:** Option, Switch, Parameter (when the CLI flag is meant)
- **Correct Example:** *The `--target` **flag** points at the project.*
- **Incorrect Example:** *The `--target` option points at the project.*

#### Technical Name: Badge
- **Part of Speech:** Noun
- **Definition:** A small SVG image that shows one metric, for example the
  SPARK level or the test result.
- **Approved Form:** Badge (singular), Badges (plural)
- **Do Not Use:** Icon, Image, Shield
- **Correct Example:** *The **badge** shows the DO-178C compliance status.*
- **Incorrect Example:** *The icon shows the DO-178C compliance status.*

#### Technical Name: Dashboard
- **Part of Speech:** Noun
- **Definition:** The web page that shows the assessment results of a target
  project. The `--serve` flag starts the dashboard.
- **Approved Form:** Dashboard (singular), Dashboards (plural)
- **Do Not Use:** Report page, Control panel, UI page
- **Correct Example:** *The **dashboard** shows the SPARK level and the test results.*
- **Incorrect Example:** *The report page shows the SPARK level and the test results.*

#### Technical Name: Machine-Integer Type
- **Part of Speech:** Noun
- **Definition:** A bounded integer type that models a machine integer of a
  target word size. Examples are `IR_Int32` and `IR_UInt64`.
- **Approved Form:** Machine-Integer Type (singular), Machine-Integer Types
  (plural)
- **Do Not Use:** Integer type (when the bounded IR type is meant), C type
- **Correct Example:** *The **machine-integer type** `IR_Int32` cannot overflow.*
- **Incorrect Example:** *The C type `IR_Int32` cannot overflow.*

#### Technical Name: Docstring
- **Part of Speech:** Noun
- **Definition:** A structured comment that documents a subprogram and counts
  toward docstring coverage. It uses tags such as `@param` and `@return`.
- **Approved Form:** Docstring (singular), Docstrings (plural)
- **Do Not Use:** Comment (when the docstring is meant), Documentation
  comment (after the first use)
- **Correct Example:** *Every subprogram has a **docstring** with a summary.*
- **Incorrect Example:** *Every subprogram has a comment with a summary.*

#### Technical Name: Cyclomatic Complexity
- **Part of Speech:** Noun
- **Definition:** A count of the independent paths through a subprogram. The
  complexity gate rejects files and subprograms above the configured limit.
- **Approved Form:** Cyclomatic Complexity (no plural)
- **Do Not Use:** Complexity (when the metric is meant), Branch count
- **Correct Example:** *The gate fails when the **cyclomatic complexity** of a subprogram is too high.*
- **Incorrect Example:** *The gate fails when the branch count of a subprogram is too high.*

#### Technical Name: LOC
- **Part of Speech:** Noun
- **Definition:** Lines of code. The complexity gate caps the LOC of a file
  and the share of the codebase that a file may hold.
- **Approved Form:** LOC (no plural)
- **Do Not Use:** Lines (ambiguous), Source lines (after the first use)
- **Correct Example:** *No file exceeds the **LOC** cap.*
- **Incorrect Example:** *No file exceeds the lines cap.*

#### Technical Name: Proof Patch
- **Part of Speech:** Noun
- **Definition:** A patch file under `.adacovex/patches` that adds SPARK
  contracts to vendored code. The prove subcommand merges the patch into a
  proof tree copy and proves the vendored code against it.
- **Approved Form:** Proof Patch (singular), Proof Patches (plural)
- **Do Not Use:** Contract patch, SPARK patch, Merge file
- **Correct Example:** *A **proof patch** adds contracts to the vendored spec.*
- **Incorrect Example:** *A contract patch adds contracts to the vendored spec.*

#### Technical Name: Version Control System (VCS)
- **Part of Speech:** Noun
- **Definition:** A system that records revisions of source files. The
  differential modes snapshot a base revision from the VCS of the target.
- **Approved Form:** Version Control System (singular), VCS (abbreviation)
- **Do Not Use:** Source control (after the first use), Repository system
- **Correct Example:** *The **VCS** of the target must be git or another supported system.*
- **Incorrect Example:** *The repository system of the target must be git or another supported system.*

#### Technical Name: Differential Assessment
- **Part of Speech:** Noun
- **Definition:** A comparison of the current tree against a base revision.
  The `--compare-base` and `--coverage-delta` flags run a differential
  assessment.
- **Approved Form:** Differential Assessment (singular), Differential
  Assessments (plural)
- **Do Not Use:** Diff run, Comparison run, Delta check
- **Correct Example:** *The **differential assessment** compares the tree against the base revision.*
- **Incorrect Example:** *The diff run compares the tree against the base revision.*

#### Technical Name: Result Cache
- **Part of Speech:** Noun
- **Definition:** The on-disk cache that reuses a prior proof or scan result
  when the inputs are unchanged. The cache keys on a content hash of the
  inputs.
- **Approved Form:** Result Cache (singular), Result Caches (plural)
- **Do Not Use:** Cache (when the result cache is meant), Artifact store
- **Correct Example:** *The **result cache** serves the proof when the inputs are unchanged.*
- **Incorrect Example:** *The artifact store serves the proof when the inputs are unchanged.*

#### Technical Name: Safety Class
- **Part of Speech:** Noun
- **Definition:** One of the IEC 62304 classes (A, B, or C) that classify the
  risk of a medical-device software item. Class C is the highest risk.
- **Approved Form:** Safety Class (singular), Safety Classes (plural)
- **Do Not Use:** Integrity class, Class (when the safety class is meant)
- **Correct Example:** *The target achieves **safety Class A** under IEC 62304.*
- **Incorrect Example:** *The target achieves integrity class A under IEC 62304.*

#### Technical Name: Man Page
- **Part of Speech:** Noun
- **Definition:** The manual page for adacovex. The `man` subcommand installs
  the page into the local man database and checks it with `man --check`.
- **Approved Form:** Man Page (singular), Man Pages (plural)
- **Do Not Use:** Manual page (after the first use), Help page
- **Correct Example:** *The **man page** embeds the binary version.*
- **Incorrect Example:** *The help page embeds the binary version.*

#### Technical Name: DO-178C
- **Part of Speech:** Noun
- **Definition:** The avionics software standard that defines the DAL levels
  A to E. adacovex assesses DO-178C compliance.
- **Approved Form:** DO-178C (exact form)
- **Do Not Use:** The avionics standard (after the first use), RTCA standard
- **Correct Example:** *adacovex assesses compliance with **DO-178C** at every DAL level.*
- **Incorrect Example:** *adacovex assesses compliance with the RTCA standard at every DAL level.*

#### Technical Name: ISO 26262
- **Part of Speech:** Noun
- **Definition:** The automotive functional-safety standard that defines the
  ASIL levels. adacovex assesses ISO 26262 compliance.
- **Approved Form:** ISO 26262 (exact form)
- **Do Not Use:** The automotive standard (after the first use)
- **Correct Example:** *The target achieves **ASIL B** under ISO 26262.*
- **Incorrect Example:** *The target achieves ASIL B under the automotive standard.*

#### Technical Name: IEC 62304
- **Part of Speech:** Noun
- **Definition:** The medical-device software standard that defines the
  safety classes A to C. adacovex assesses IEC 62304 compliance.
- **Approved Form:** IEC 62304 (exact form)
- **Do Not Use:** The medical standard (after the first use)
- **Correct Example:** *The target achieves **safety Class A** under IEC 62304.*
- **Incorrect Example:** *The target achieves safety Class A under the medical standard.*

### Category: Hardware and System Entities

#### Technical Name: CPU Core
- **Part of Speech:** Noun
- **Definition:** A logical processor on the host machine. The detection
  counts CPU cores to resolve gnatprove parallelism.
- **Approved Form:** CPU Core (singular), CPU Cores (plural)
- **Do Not Use:** Processor (when the core is meant), CPU (when one core is
  meant)
- **Correct Example:** *The tool detects 16 **CPU cores** on the host.*
- **Incorrect Example:** *The tool detects 16 processors on the host.*

#### Technical Name: Host
- **Part of Speech:** Noun
- **Definition:** The machine that runs adacovex. The host is separate from
  the target project that adacovex assesses.
- **Approved Form:** Host (singular), Hosts (plural)
- **Do Not Use:** Local machine, Computer, System (when the host is meant)
- **Correct Example:** *The tool probes the **host** CPU count.*
- **Incorrect Example:** *The tool probes the local machine CPU count.*

#### Technical Name: Target
- **Part of Speech:** Noun
- **Definition:** The project that adacovex assesses. The `--target` flag
  points at the target project.
- **Approved Form:** Target (singular), Targets (plural)
- **Do Not Use:** Project (when the assessed project is meant), Subject,
  Audited tree
- **Correct Example:** *The **target** is a SPARK project in git.*
- **Incorrect Example:** *The subject is a SPARK project in git.*

### Category: Code Identifier Names

#### Technical Name: adacovex
- **Part of Speech:** Noun
- **Definition:** The name of this tool. Use the exact lower-case spelling.
- **Approved Form:** adacovex
- **Do Not Use:** Ada Covex, Adacovex, the tool (when the name is meant)
- **Correct Example:** *Run **adacovex** with the `prove` subcommand.*
- **Incorrect Example:** *Run Adacovex with the prove subcommand.*

#### Technical Name: covex
- **Part of Speech:** Noun
- **Definition:** The alias name for the adacovex binary, used in Alire
  crates. The release bundle ships both names.
- **Approved Form:** covex
- **Do Not Use:** Covex, the binary (when the name is meant)
- **Correct Example:** *The bundle contains **covex** as an alias for adacovex.*
- **Incorrect Example:** *The bundle contains Covex as an alias for adacovex.*

#### Technical Name: Alire
- **Part of Speech:** Noun
- **Definition:** The Ada package manager and its ecosystem. The `alr`
  command is its command-line tool.
- **Approved Form:** Alire
- **Do Not Use:** Package manager (when Alire is meant), Ada package
  manager (after the first use)
- **Correct Example:** ***Alire** resolves the gnatprove dependency.*
- **Incorrect Example:** *The package manager resolves the gnatprove dependency.*

#### Technical Name: alr
- **Part of Speech:** Noun
- **Definition:** The command-line tool of Alire. Use the exact lower-case
  spelling when the command is meant.
- **Approved Form:** alr
- **Do Not Use:** Alire (when the command is meant), the installer
- **Correct Example:** *Run `alr build` to build the project.*
- **Incorrect Example:** *Run Alire build to build the project.*

#### Technical Name: GNAT
- **Part of Speech:** Noun
- **Definition:** The GNU Ada compiler suite. adacovex uses only the GNAT
  runtime.
- **Approved Form:** GNAT (all capitals)
- **Do Not Use:** Compiler (when GNAT is meant), Gnat, gnat
- **Correct Example:** *The binary depends only on the **GNAT** runtime.*
- **Incorrect Example:** *The binary depends only on the Gnat runtime.*

#### Technical Name: gnatprove
- **Part of Speech:** Noun
- **Definition:** The SPARK proof tool. The command is `gnatprove`. The
  product name is GNATprove.
- **Approved Form:** gnatprove (for the command), GNATprove (for the
  product)
- **Do Not Use:** Prover (when gnatprove is meant), Proof tool (after the
  first use)
- **Correct Example:** *The `prove` subcommand runs **gnatprove** on the target.*
- **Incorrect Example:** *The prove subcommand runs the prover on the target.*

#### Technical Name: gnatdoc
- **Part of Speech:** Noun
- **Definition:** The Ada documentation generator that produces the API
  reference from source docstrings.
- **Approved Form:** gnatdoc (exact lower-case)
- **Do Not Use:** Doc generator, Documentation tool (when gnatdoc is meant)
- **Correct Example:** *`make doc` runs **gnatdoc** on the Ada sources.*
- **Incorrect Example:** *`make doc` runs the doc generator on the Ada sources.*

#### Technical Name: Manifest
- **Part of Speech:** Noun
- **Definition:** The Alire manifest file of a crate. The files are
  `alire.toml` and `alire-dev.toml`.
- **Approved Form:** Manifest (singular), Manifests (plural)
- **Do Not Use:** Configuration file, Metadata file, TOML file (when the
  manifest is meant)
- **Correct Example:** *The **manifest** declares the gnatprove dependency.*
- **Incorrect Example:** *The configuration file declares the gnatprove dependency.*

#### Technical Name: alire.lock
- **Part of Speech:** Noun
- **Definition:** The solved dependency list that Alire writes. It records
  the exact versions of every resolved crate.
- **Approved Form:** alire.lock (exact file name)
- **Do Not Use:** Lock file (when alire.lock is meant), Dependency file
- **Correct Example:** *The parser reads **alire.lock** to build the dependency graph.*
- **Incorrect Example:** *The parser reads the lock file to build the dependency graph.*

#### Technical Name: GNAT Project File (.gpr)
- **Part of Speech:** Noun
- **Definition:** A build description file with the `.gpr` extension. The
  proof run targets the root `.gpr` file of the target project.
- **Approved Form:** GNAT Project File (singular), .gpr (abbreviation)
- **Do Not Use:** Project file (when the .gpr file is meant), Build file
- **Correct Example:** *gnatprove runs against the root **.gpr** file.*
- **Incorrect Example:** *gnatprove runs against the root build file.*

#### Technical Name: gnatprove.out
- **Part of Speech:** Noun
- **Definition:** The output file that gnatprove writes. It contains the
  proof summary and the VC counts. The assessment pipeline parses it.
- **Approved Form:** gnatprove.out (exact file name)
- **Do Not Use:** Proof output (when the file is meant), The out file
- **Correct Example:** *The parser reads `obj/gnatprove/gnatprove.out`.*
- **Incorrect Example:** *The parser reads the proof output file.*

#### Technical Name: AUnit
- **Part of Speech:** Noun
- **Definition:** The Ada unit-test framework. The test-result parser reads
  AUnit output.
- **Approved Form:** AUnit
- **Do Not Use:** Test framework (when AUnit is meant), Test suite (when the
  framework is meant)
- **Correct Example:** *The native tests run under **AUnit**.*
- **Incorrect Example:** *The native tests run under the test framework.*

#### Technical Name: SPARK_Mode
- **Part of Speech:** Noun
- **Definition:** The Ada pragma or aspect that enables SPARK analysis for a
  unit. Use the exact spelling with the underscore.
- **Approved Form:** SPARK_Mode (exact spelling)
- **Do Not Use:** SPARK mode, Spark_Mode, Spark mode
- **Correct Example:** *The package declares `SPARK_Mode => On`.*
- **Incorrect Example:** *The package declares SPARK mode on.*

#### Technical Name: HLR Tag
- **Part of Speech:** Noun
- **Definition:** A source comment of the form `-- HLR-XXXX` that traces a
  source element to a high-level requirement.
- **Approved Form:** HLR Tag (singular), HLR Tags (plural), HLR-XXXX (the
  tag form)
- **Do Not Use:** Tag (when the HLR tag is meant), Annotation
- **Correct Example:** *The subprogram carries the **HLR tag** `-- HLR-ARCH`.*
- **Incorrect Example:** *The subprogram carries the annotation `-- HLR-ARCH`.*

#### Technical Name: CycloneDX
- **Part of Speech:** Noun
- **Definition:** The SBOM exchange schema that adacovex uses for the
  CycloneDX 1.5 JSON SBOM format.
- **Approved Form:** CycloneDX (exact form)
- **Do Not Use:** Cyclonedx, Cyclone DX, SBOM format (when CycloneDX is
  meant)
- **Correct Example:** *The `sbom` subcommand emits **CycloneDX** 1.5 JSON.*
- **Incorrect Example:** *The sbom subcommand emits Cyclone DX 1.5 JSON.*

#### Technical Name: SPDX
- **Part of Speech:** Noun
- **Definition:** The software package data exchange schema that adacovex
  uses for the SPDX 2.3 JSON SBOM format.
- **Approved Form:** SPDX (exact capitals)
- **Do Not Use:** Spdx, spdx, License schema (when SPDX is meant)
- **Correct Example:** *The `sbom` subcommand also emits **SPDX** 2.3 JSON.*
- **Incorrect Example:** *The sbom subcommand also emits Spdx 2.3 JSON.*

#### Technical Name: ANSI
- **Part of Speech:** Modifier
- **Definition:** The escape-code standard used for colour output in a
  terminal. Always use it with the noun codes.
- **Approved Form:** ANSI (as modifier, for example ANSI escape codes)
- **Do Not Use:** Terminal codes, Colour codes
- **Correct Example:** *The report uses **ANSI** escape codes for colour.*
- **Incorrect Example:** *The report uses terminal codes for colour.*

#### Technical Name: NO_COLOR
- **Part of Speech:** Noun
- **Definition:** The environment variable that disables colour output. When
  it is set, the ANSI report prints without colour.
- **Approved Form:** NO_COLOR (exact capitals)
- **Do Not Use:** No color variable, The colour switch (when the variable is
  meant)
- **Correct Example:** *The report honours the **NO_COLOR** environment variable.*
- **Incorrect Example:** *The report honours the No color environment variable.*

#### Technical Name: gnatformat
- **Part of Speech:** Noun
- **Definition:** The GNAT source formatter. The `make fmt` target runs
  gnatformat on the Ada sources.
- **Approved Form:** gnatformat (exact lower-case)
- **Do Not Use:** Formatter (when gnatformat is meant), Gnat format
- **Correct Example:** *`make fmt` runs **gnatformat** on the sources.*
- **Incorrect Example:** *`make fmt` runs the formatter on the sources.*

#### Technical Name: Verification Report
- **Part of Speech:** Noun
- **Definition:** The generated report file `VERIFICATION.md`. It records the
  assessment results of the target project.
- **Approved Form:** Verification Report (singular), VERIFICATION.md (the
  file name)
- **Do Not Use:** Report file (when VERIFICATION.md is meant), Assessment
  report (after the first use)
- **Correct Example:** *The renderer writes the **verification report** to `VERIFICATION.md`.*
- **Incorrect Example:** *The renderer writes the report file to `VERIFICATION.md`.*

#### Technical Name: Traceability Matrix
- **Part of Speech:** Noun
- **Definition:** The generated report file `TRACE.md`. It maps every
  high-level requirement to the source elements that implement it.
- **Approved Form:** Traceability Matrix (singular), TRACE.md (the file
  name)
- **Do Not Use:** Trace table, Mapping file (when TRACE.md is meant)
- **Correct Example:** *The renderer writes the **traceability matrix** to `TRACE.md`.*
- **Incorrect Example:** *The renderer writes the mapping file to `TRACE.md`.*
