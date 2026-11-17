# Adacovex.Types

Host machine word size in bits, auto-detected from the Ada runtime
(8, 16, 32, or 64). Fixed-size path and line buffers scale with it.
Builds on narrower hosts use proportionally smaller limits.

**See also:** [Standards](../usage/standards.md) | [DAL Levels](adacovex-dal-levels.md)

> **Note:** All items in this package are public.

## Types

### type Compliance_Standard

```ada
type Compliance_Standard is (DO_178C, ISO_26262, IEC_62304);
```

> Compliance standard target for the assessment. DO_178C covers avionics software. ISO_26262 covers automotive functional safety. IEC_62304 covers medical-device software. All three share the same evidence (SPARK proof level, passing tests, HLR traceability). The standard only re-labels the integrity levels.

### type Component_Kind

```ada
type Component_Kind is (Root_Component, Dependency_Component);
```

> SBOM component kind. The root project is the project being described. A library dependency is resolved from the dependency graph.

### type Component_Scope

```ada
type Component_Scope is
(Scope_Base,
Scope_Dev,
Scope_Transitive,
Scope_Vendored,
Scope_System,
Scope_Test);
```

> Dependency scope for an SBOM component. A publishing dependency is declared in alire.toml (base). A development-only dependency is declared only in alire-dev.toml (dev). A transitive crate is resolved from alire.lock or GPR with clauses that no manifest names directly (transitive). A vendored package is overlaid by a .adacovex/patches/ docstring patch (vendored). A system-tool dependency is a program installed on PATH that the project's build or dev files reference (system) -- for example python3, git, or gnatprove. System tools carry a resolved version but no external link or licence. A test dependency is used only by the project's tests: it is declared under a [[test-depends-on]] manifest section, or it is with-claused only from test project files (a .gpr under a tests/ test/ or t/ directory, or a test-named project such as test_runner.gpr). A dependency declared in a test-labelled section of a supported-language manifest is test too: package.json sections whose key contains "test" (for example "testDependencies"), Cargo's [dev-dependencies] (and any section containing "test"), composer's require-dev, Gemfile `group :test` blocks, pom.xml <scope>test</scope> dependencies, pyproject.toml optional-dependencies extras containing "test", and Package.swift .testTarget dependencies. A vendored component whose name carries the test label (full name or its last segment after any '/' or ':', for example @playwright/test, github.com/stretchr/testify, org.testng:testng) is test as well, and the same heuristic applies to lockfile-resolved names (pnpm-lock.yaml, package-lock.json, yarn.lock, Cargo.lock, alire.lock). Scope_Test is last so the stream-serialized cache positions of the older scopes stay stable across releases.

### type DAL_Level

```ada
type DAL_Level is (DAL_A, DAL_B, DAL_C, DAL_D, DAL_E);
```

> DO-178C design assurance level from DAL_A (most critical) to DAL_E (no safety effect).

### type DAL_Status

```ada
type DAL_Status is (Achieved, Unmet);
```

> Outcome of a DAL assessment. Achieved means every criterion for the target level passed. Unmet means at least one failed.

### type Dashboard_Theme

```ada
type Dashboard_Theme is (System_Theme, Light_Theme, Dark_Theme);
```

> Dashboard colour theme for --serve. System_Theme follows the browser's prefers-color-scheme. Light_Theme and Dark_Theme force a specific theme regardless of the OS preference.

### type Dependency_Scope_Flags

```ada
type Dependency_Scope_Flags is record
Is_Dev    : Boolean := False;
Is_System : Boolean := False;
end record;
```

> Record whether a dependency is declared for development as well as whether the resolved component is a system tool. This preserves both facts when one component is named in a dev manifest and detected on PATH.

### type Desc_Field

```ada
subtype Desc_Field is String (1 .. Max_Desc_Str);
```

> Bounded description text. A copy stores the leading Max_Desc_Str bytes and clamps the rest, with its length kept beside it.

### type Docstring_Metrics

```ada
type Docstring_Metrics is record
Total_Subprograms   : Natural := 0;
Documented_Subprogs : Natural := 0;
Total_Parameters    : Natural := 0;
Documented_Params   : Natural := 0;
Total_Returns       : Natural := 0;
Documented_Returns  : Natural := 0;
Coverage_Pct        : Natural := 0;
end record;
```

> Docstring coverage over the scanned tree: how many subprograms, parameters, and return values carry a docstring, and the share of them that do.

### type HLR_Tag_Entry

```ada
type HLR_Tag_Entry is record
Tag : String (1 .. Max_Id_Str);
Len : Natural := 0;
end record;
```

> One HLR traceability tag found in a source file, with the length of its text.

### type Name_Field

```ada
subtype Name_Field is String (1 .. Max_Filename);
```

> Bounded file or crate name. A copy clamps at Max_Filename and records its length in a companion field.

### type Path_Field

```ada
subtype Path_Field is String (1 .. Max_Path);
```

> Bounded filesystem path. A copy clamps at Max_Path and records its length in a companion field.

### type Proof_Coverage

```ada
type Proof_Coverage is record
Measured      : Boolean := False;
Subs_Proved   : Natural := 0;
Subs_Total    : Natural := 0;
Checks_Proved : Natural := 0;
Checks_Total  : Natural := 0;
end record;
```

> Full proof coverage as Adacovex.Spark_Coverage measures it: every subprogram the prover considered is proved. The check counts are carried alongside for the verbose report. A proof artefact alone cannot establish this, so the assessment pipeline fills the record in after it has measured the SPARK coverage report. Platinum requires it; a record whose Measured flag is False never grants Platinum.

### type Proof_Summary

```ada
type Proof_Summary is record
Total_VCs          : Natural := 0;
Proved_VCs         : Natural := 0;
Flow_Checks        : Natural := 0;
Flow_Proved        : Natural := 0;
Init_Checks        : Natural := 0;
Init_Proved        : Natural := 0;
Runtime_Checks     : Natural := 0;
Runtime_Proved     : Natural := 0;
Assertions         : Natural := 0;
Assert_Proved      : Natural := 0;
Functional_Ct      : Natural := 0;
Functional_Proved  : Natural := 0;
Termination_Ct     : Natural := 0;
Termination_Proved : Natural := 0;
Justified          : Natural := 0;
Unproved           : Natural := 0;
Level              : SPARK_Level := Stone;
Units_Analyzed     : Natural := 0;
Units_Skipped      : Natural := 0;
Coverage           : Proof_Coverage;
end record;
```

> Totals from one GNATprove run: verified conditions, flow and initialisation checks, runtime checks, assertions, termination, and the level they earn.

### type SBOM_Format_Kind

```ada
type SBOM_Format_Kind is (CycloneDX_JSON, SPDX_JSON, Markdown);
```

> SBOM output format. CycloneDX_JSON and SPDX_JSON emit machine-readable JSON documents. Markdown emits a human-readable compliance table.

### type Spark_Group_Kind

```ada
type Spark_Group_Kind is (Group_File, Group_Folder, Group_Package);
```

> How a SPARK-coverage report groups its rows. Group_File keys rows by the Ada source unit, Group_Folder by the folder under the target directory, and Group_Package by the Ada package name.

### type SPARK_Level

```ada
type SPARK_Level is (Stone, Bronze, Silver, Gold, Platinum);
```

> SPARK assurance level from Stone (weakest) to Platinum (strongest). The assessment compares it with the level a DAL requires.

### type Spark_Metric_Kind

```ada
type Spark_Metric_Kind is
(Metric_Statements, Metric_Subprograms, Metric_Checks);
```

> Which of the three SPARK coverage metrics a report or a threshold gate uses. Each metric answers a different question, so every percentage in a SPARK-coverage report names the one it belongs to. Metric_Statements  proved executable statements / all executable statements (how much of the code is verified) Metric_Subprograms proved subprograms / subprograms gnatprove considered (how much of the design surface is verified) Metric_Checks      discharged checks / checks the prover reported (what the prover actually discharged)

### type Spark_Off_Class

```ada
type Spark_Off_Class is
(Off_None, Off_Irreducible, Off_IO_Bound, Off_Work_Queue);
```

> Why a subprogram is outside the proof. Off_None means the subprogram is proved. Off_Irreducible is one of the documented packages that can never be in SPARK (a non-formal Ada.Containers instantiation). Off_IO_Bound is a body the prover cannot analyse at all because it performs input or output. Off_Work_Queue is a default-off pure-logic body: provable in principle, so it is the backlog.

### type Spark_Report_Kind

```ada
type Spark_Report_Kind is (Spark_Text, Spark_JSON);
```

> Output shape of the spark-coverage report.

### type Subprogram_Info

```ada
type Subprogram_Info is record
Name          : Desc_Field;
Name_Len      : Natural := 0;
Line_Number   : Natural := 0;
Has_Docstring : Boolean := False;
Doc_Param_Ct  : Natural := 0;
Has_Return    : Boolean := False;
Doc_Return    : Boolean := False;
end record;
```

> One subprogram the scanner found, with the docstring facts the docstring-coverage metric counts.

### type Test_Metrics

```ada
type Test_Metrics is record
Category   : Desc_Field;
Cat_Len    : Natural := 0;
Test_Count : Natural := 0;
Status     : Test_Status := Pass;
end record;
```

> Pass and fail counts for one test category.

### type Test_Status

```ada
type Test_Status is (Pass, Fail);
```

> Outcome of one test category: every test passed, or at least one failed.

## Functions

### function Is_Valid_ASIL (S : Standard.String) return Standard.Boolean `[Global]`

> Whether S is a valid ASIL level ("A".."D" or "QM", case-insensitive).

| Parameter | Description |
|-----------|-------------|
| `S` | Candidate ASIL level string. |

**Returns:** True when S names a valid ASIL level.

### function Is_Valid_Class (S : Standard.String) return Standard.Boolean `[Global]`

> Whether S is a valid IEC 62304 safety class ("A".."C", case-insensitive).

| Parameter | Description |
|-----------|-------------|
| `S` | Candidate safety-class string. |

**Returns:** True when S names a valid safety class.

### function Is_Valid_Theme (S : Standard.String) return Standard.Boolean `[Global]`

> Whether S names a valid dashboard theme ("system", "light", or "dark", case-insensitive).

| Parameter | Description |
|-----------|-------------|
| `S` | Candidate theme string. |

**Returns:** True when S names a valid dashboard theme.

### function Standard_Level_Name (Standard : Adacovex.Types.Compliance_Standard; Level : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]`

> Human-readable integrity-level label for a standard and a rigour tier. DO-178C keeps "DAL-A".."DAL-E". ISO 26262 maps A..E to "ASIL D", "ASIL C", "ASIL B", "ASIL A", "QM". IEC 62304 maps to "Class C", "Class B", "Class A", "No class", "No class".

| Parameter | Description |
|-----------|-------------|
| `Level` | Rigour tier (reused DAL level). |
| `Standard` | Compliance standard. |

**Returns:** The standard-specific level label.

### function Standard_Slug (S : Adacovex.Types.Compliance_Standard) return Standard.String `[Post]` `[Global]`

> Lowercase filename slug for a standard's badge file. The slug is "do178c", "iso26262", or "iec62304".

| Parameter | Description |
|-----------|-------------|
| `S` | Compliance standard. |

**Returns:** The standard's badge-file slug.

### function To_ASIL (S : Standard.String) return Adacovex.Types.DAL_Level `[Global]`

> Parse an ASIL level into the shared rigour tier. ASIL A--D map to DAL_D--DAL_A (ASIL D is the most rigorous). QM maps to DAL_E (no safety effect). The function accepts "A".."D" and "QM" case-insensitively. It defaults to DAL_C (ASIL B) on parse failure.

| Parameter | Description |
|-----------|-------------|
| `S` | ASIL level (A-D or QM, case-insensitive). |

**Returns:** Shared rigour tier (defaults to DAL_C on failure).

### function To_Class (S : Standard.String) return Adacovex.Types.DAL_Level `[Global]`

> Parse an IEC 62304 software safety class into the shared rigour tier. Class A--C map to DAL_C--DAL_A (Class C is the most rigorous). The function accepts "A".."C" case-insensitively. It defaults to DAL_C (Class A) on parse failure.

| Parameter | Description |
|-----------|-------------|
| `S` | Safety class (A-C, case-insensitive). |

**Returns:** Shared rigour tier (defaults to DAL_C on failure).

### function To_DAL (S : Standard.String) return Adacovex.Types.DAL_Level `[Global]`

> Parse a single-letter DAL code string into a DAL_Level. The function accepts both upper and lower case. It defaults to DAL_C on parse failure.

| Parameter | Description |
|-----------|-------------|
| `S` | Single-letter DAL code (A-E, case-insensitive). |

**Returns:** Converted DAL_Level (defaults to DAL_C on failure).

### function To_Standard (S : Standard.String) return Adacovex.Types.Compliance_Standard `[Global]`

> Parse a standard name into a Compliance_Standard. The function accepts "do178c"/"do-178c", "iso26262"/"iso-26262", and "iec62304"/"iec-62304" (case-insensitive). It defaults to DO_178C on parse failure.

| Parameter | Description |
|-----------|-------------|
| `S` | Standard name. |

**Returns:** Converted Compliance_Standard (defaults to DO_178C).

### function To_String (S : Adacovex.Types.Compliance_Standard) return Standard.String `[Post]` `[Global]`

> Convert a Test_Status ("Pass" or "Fail") to "PASS" or "FAIL".

| Parameter | Description |
|-----------|-------------|
| `S` | Test status to name. |

**Returns:** "PASS" or "FAIL".

### function To_String (L : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]`

> Convert a DAL_Level to its single-letter code ('A' through 'E').

| Parameter | Description |
|-----------|-------------|
| `L` | DAL level to convert. |

**Returns:** Single-letter DAL code.

### function To_String (S : Adacovex.Types.DAL_Status) return Standard.String `[Post]` `[Global]`

> Convert a Test_Status ("Pass" or "Fail") to "PASS" or "FAIL".

| Parameter | Description |
|-----------|-------------|
| `S` | Test status to name. |

**Returns:** "PASS" or "FAIL".

### function To_String (T : Adacovex.Types.Dashboard_Theme) return Standard.String `[Post]` `[Global]`

> Convert a Dashboard_Theme to its CLI value. The value is "system", "light", or "dark".

| Parameter | Description |
|-----------|-------------|
| `T` | Dashboard theme. |

**Returns:** The theme's CLI name.

### function To_String (G : Adacovex.Types.Spark_Group_Kind) return Standard.String `[Global]`

> Convert a Spark_Group_Kind to its CLI name: "file", "folder", or "package".

| Parameter | Description |
|-----------|-------------|
| `G` | Group kind. |

**Returns:** The group kind's CLI name.

### function To_String (L : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]`

> Convert a DAL_Level to its single-letter code ('A' through 'E').

| Parameter | Description |
|-----------|-------------|
| `L` | DAL level to convert. |

**Returns:** Single-letter DAL code.

### function To_String (M : Adacovex.Types.Spark_Metric_Kind) return Standard.String `[Global]`

> Convert a Spark_Metric_Kind to its CLI name: "statements", "subprograms", or "vcs". Every percentage in a SPARK-coverage report carries this label so a reader never has to guess which metric a number belongs to.

| Parameter | Description |
|-----------|-------------|
| `M` | Metric kind. |

**Returns:** The metric's CLI name.

### function To_String (C : Adacovex.Types.Spark_Off_Class) return Standard.String `[Global]`

> Convert a Spark_Off_Class to its report label: "none", "irreducible", "io-bound", "work-queue", or "not-covered".

| Parameter | Description |
|-----------|-------------|
| `C` | Off class. |

**Returns:** The class label.

### function To_String (S : Adacovex.Types.Test_Status) return Standard.String `[Post]` `[Global]`

> Convert a Test_Status ("Pass" or "Fail") to "PASS" or "FAIL".

| Parameter | Description |
|-----------|-------------|
| `S` | Test status to name. |

**Returns:** "PASS" or "FAIL".

### function To_Theme (S : Standard.String) return Adacovex.Types.Dashboard_Theme `[Global]`

> Parse a dashboard theme name into a Dashboard_Theme. The function accepts "system", "light", and "dark" case-insensitively. It defaults to System_Theme on parse failure.

| Parameter | Description |
|-----------|-------------|
| `S` | Theme name. |

**Returns:** Converted Dashboard_Theme (defaults to System_Theme).
