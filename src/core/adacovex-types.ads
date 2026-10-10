--  All domain types used across the adacovex tool chain.
--  Package and subprogram collections use Ada.Containers.Vectors
--  (unbounded, up to Natural'Last ~ 2.1B). Fixed-size buffers
--  (Max_Path, Max_Line, Max_Desc_Str, and more) are bounded at compile time
--  with generous production-suitable limits (Max_Path=4096, Max_Line=262144
--  on a 64-bit host). Max_Path and Max_Line scale with the host word size
--  (System.Word_Size). Builds on narrower hosts use proportionally smaller
--  limits. Max_Line is large enough to read single-line declarations from
--  heavily generated Ada sources without silently draining them.
--  HLR-METRICS: Docstring_Metrics type
--  HLR-PROOF: Proof_Summary type
--  HLR-TEST: Test_Summary type
--  HLR-COMPLIANCE: DAL_Assessment type
--  HLR-DAL-A: DAL_Level (DAL_A)
--  HLR-DAL-B: DAL_Level (DAL_B)
--  HLR-DAL-C: DAL_Level (DAL_C)
--  HLR-DAL-D: DAL_Level (DAL_D)
--  HLR-DAL-E: DAL_Level (DAL_E)
--  HLR-SBOM: SBOM component and format types

with Ada.Containers.Vectors;
with System;

package Adacovex.Types is
   pragma SPARK_Mode (On);

   --  Host machine word size in bits, auto-detected from the Ada runtime
   --  (8, 16, 32, or 64). Fixed-size path and line buffers scale with it.
   --  Builds on narrower hosts use proportionally smaller limits.
   Host_Word_Bits : constant := System.Word_Size;

   --  Path and line buffers scale with the host word size. On a 64-bit host
   --  they keep their classic values (4096 / 262144). Identifier and
   --  description limits (Max_Id_Str, Max_Desc_Str, Max_Filename) are
   --  semantic, not storage-size dependent, and remain fixed.
   Max_Path     : constant := 64 * Host_Word_Bits;
   Max_Line     : constant := 4096 * Host_Word_Bits;
   Max_Id_Str   : constant := 64;
   Max_Desc_Str : constant := 128;
   Max_Filename : constant := 128;

   subtype Desc_Field is String (1 .. Max_Desc_Str);
   subtype Name_Field is String (1 .. Max_Filename);
   subtype Path_Field is String (1 .. Max_Path);

   type HLR_Tag_Entry is record
      Tag : String (1 .. Max_Id_Str);
      Len : Natural := 0;
   end record;

   type SPARK_Level is (Stone, Bronze, Silver, Gold, Platinum);

   type DAL_Level is (DAL_A, DAL_B, DAL_C, DAL_D, DAL_E);

   --  Compliance standard target for the assessment. DO_178C covers
   --  avionics software. ISO_26262 covers automotive functional safety.
   --  IEC_62304 covers medical-device software. All three share the same
   --  evidence (SPARK proof level, passing tests, HLR traceability). The
   --  standard only re-labels the integrity levels.
   type Compliance_Standard is (DO_178C, ISO_26262, IEC_62304);

   type DAL_Status is (Achieved, Unmet);

   type Test_Status is (Pass, Fail);

   --  Dashboard colour theme for --serve. System_Theme follows the
   --  browser's prefers-color-scheme. Light_Theme and Dark_Theme force a
   --  specific theme regardless of the OS preference.
   type Dashboard_Theme is (System_Theme, Light_Theme, Dark_Theme);

   --  SBOM output format. CycloneDX_JSON and SPDX_JSON emit machine-readable
   --  JSON documents. Markdown emits a human-readable compliance table.
   --  HLR-SBOM: SBOM format kind
   type SBOM_Format_Kind is (CycloneDX_JSON, SPDX_JSON, Markdown);

   --  Which of the three SPARK coverage metrics a report or a threshold gate
   --  uses. Each metric answers a different question, so every percentage in
   --  a SPARK-coverage report names the one it belongs to.
   --    Metric_Statements  proved executable statements / all executable
   --                       statements (how much of the code is verified)
   --    Metric_Subprograms proved subprograms / subprograms gnatprove
   --                       considered (how much of the design surface is
   --                       verified)
   --    Metric_Checks      discharged checks / checks the prover reported
   --                       (what the prover actually discharged)
   --  HLR-SPARK: SPARK coverage metrics
   type Spark_Metric_Kind is
     (Metric_Statements, Metric_Subprograms, Metric_Checks);

   --  How a SPARK-coverage report groups its rows. Group_File keys rows by
   --  the Ada source unit, Group_Folder by the folder under the target
   --  directory, and Group_Package by the Ada package name.
   type Spark_Group_Kind is (Group_File, Group_Folder, Group_Package);

   --  Why a subprogram is outside the proof. Off_None means the subprogram
   --  is proved. Off_Irreducible is one of the documented packages that can
   --  never be in SPARK (a non-formal Ada.Containers instantiation).
   --  Off_IO_Bound is a body the prover cannot analyse at all because it
   --  performs input or output. Off_Work_Queue is a default-off pure-logic
   --  body: provable in principle, so it is the backlog.
   type Spark_Off_Class is
     (Off_None, Off_Irreducible, Off_IO_Bound, Off_Work_Queue);

   --  Output shape of the spark-coverage report.
   type Spark_Report_Kind is (Spark_Text, Spark_JSON);

   --  SBOM component kind. The root project is the project being described.
   --  A library dependency is resolved from the dependency graph.
   type Component_Kind is (Root_Component, Dependency_Component);

   --  Dependency scope for an SBOM component. A publishing dependency is
   --  declared in alire.toml (base). A development-only dependency is
   --  declared only in alire-dev.toml (dev). A transitive crate is resolved
   --  from alire.lock or GPR with clauses that no manifest names directly
   --  (transitive). A vendored package is overlaid by a .adacovex/patches/
   --  docstring patch (vendored). A system-tool dependency is a program
   --  installed on PATH that the project's build or dev files reference
   --  (system) -- for example python3, git, or gnatprove. System tools
   --  carry a resolved version but no external link or licence. A test
   --  dependency is used only by the project's tests: it is declared under
   --  a [[test-depends-on]] manifest section, or it is with-claused only
   --  from test project files (a .gpr under a tests/ test/ or t/ directory,
   --  or a test-named project such as test_runner.gpr). A dependency
   --  declared in a test-labelled section of a supported-language manifest
   --  is test too: package.json sections whose key contains "test" (for
   --  example "testDependencies"), Cargo's [dev-dependencies] (and any
   --  section containing "test"), composer's require-dev, Gemfile
   --  `group :test` blocks, pom.xml <scope>test</scope> dependencies,
   --  pyproject.toml optional-dependencies extras containing "test", and
   --  Package.swift .testTarget dependencies. A vendored component whose
   --  name carries the test label (full name or its last segment after any
   --  '/' or ':', for example @playwright/test,
   --  github.com/stretchr/testify, org.testng:testng) is test as well,
   --  and the same heuristic applies to lockfile-resolved names
   --  (pnpm-lock.yaml, package-lock.json, yarn.lock, Cargo.lock,
   --  alire.lock). Scope_Test is last so the
   --  stream-serialized cache positions of the older scopes stay stable
   --  across releases.
   --  HLR-SBOM: SBOM dependency scope
   type Component_Scope is
     (Scope_Base,
      Scope_Dev,
      Scope_Transitive,
      Scope_Vendored,
      Scope_System,
      Scope_Test);

   --  Record whether a dependency is declared for development as well as
   --  whether the resolved component is a system tool. This preserves both
   --  facts when one component is named in a dev manifest and detected on PATH.
   type Dependency_Scope_Flags is record
      Is_Dev    : Boolean := False;
      Is_System : Boolean := False;
   end record;

   type Subprogram_Info is record
      Name          : Desc_Field;
      Name_Len      : Natural := 0;
      Line_Number   : Natural := 0;
      Has_Docstring : Boolean := False;
      Doc_Param_Ct  : Natural := 0;
      Has_Return    : Boolean := False;
      Doc_Return    : Boolean := False;
   end record;

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
   end record;

   type Test_Metrics is record
      Category   : Desc_Field;
      Cat_Len    : Natural := 0;
      Test_Count : Natural := 0;
      Status     : Test_Status := Pass;
   end record;

   type Docstring_Metrics is record
      Total_Subprograms   : Natural := 0;
      Documented_Subprogs : Natural := 0;
      Total_Parameters    : Natural := 0;
      Documented_Params   : Natural := 0;
      Total_Returns       : Natural := 0;
      Documented_Returns  : Natural := 0;
      Coverage_Pct        : Natural := 0;
   end record;

   package Implementation is
      --  Non-SPARK container types. SPARK forbids instantiating the
      --  non-formal Ada.Containers in SPARK_Mode On code: gnatprove rejects
      --  such instantiations ("not allowed in SPARK (due to entity declared
      --  with SPARK_Mode Off)"; see docs/proof/16.1.0-ledger.md). This
      --  package and Adacovex.Complexity are the only two SPARK_Mode (Off)
      --  packages in the codebase, both for the same reason.
      pragma SPARK_Mode (Off);
      package Subprogram_Vectors is new
        Ada.Containers.Vectors (Positive, Subprogram_Info);

      package HLR_Tag_Vectors is new
        Ada.Containers.Vectors (Positive, HLR_Tag_Entry);

      type Package_Info is record
         Name        : Name_Field;
         Name_Len    : Natural := 0;
         File_Path   : Path_Field;
         Path_Len    : Natural := 0;
         Subprograms : Subprogram_Vectors.Vector;
         HLR_Tags    : HLR_Tag_Vectors.Vector;

         --  Per-file opt-out marker carried by the file's leading comment
         --  block (see Adacovex.Opt_Outs). Docstrings_Opt_Out removes the
         --  package from the docstring-coverage metrics. It is set by the
         --  source scanner when it reads the file header and is False
         --  otherwise. (The SPARK-proof opt-out is enforced by the prove
         --  runner's own -u unit walk, never through the scan records.)
         Docstrings_Opt_Out : Boolean := False;
      end record;

      package Package_Vectors is new
        Ada.Containers.Vectors (Positive, Package_Info);

      package Test_Metrics_Vectors is new
        Ada.Containers.Vectors (Positive, Test_Metrics);

      type Test_Summary is record
         Categories   : Test_Metrics_Vectors.Vector;
         Total_Passed : Natural := 0;
         Total_Failed : Natural := 0;
      end record;

      package DAL_Failure_Vectors is new
        Ada.Containers.Vectors (Positive, Desc_Field);

      type DAL_Assessment is record
         Target_DAL             : DAL_Level := DAL_C;
         Standard               : Compliance_Standard := DO_178C;
         Status                 : DAL_Status := Unmet;
         HLR_Total              : Natural := 0;
         HLR_Found              : Natural := 0;
         LLR_Total              : Natural := 0;
         LLR_Found              : Natural := 0;
         All_Subprograms_Traced : Boolean := False;
         Orphan_Tags            : Boolean := False;
         Tests_Passing          : Boolean := False;
         Min_SPARK_Level_Met    : Boolean := False;
         Failed_Reasons         : DAL_Failure_Vectors.Vector;
      end record;

      type Badge_Config is record
         Spark_Lvl   : SPARK_Level := Stone;
         Test_Summ   : Test_Summary;
         DAL_Assess  : DAL_Assessment;
         Show_Spark  : Boolean := True;
         Show_Tests  : Boolean := True;
         Show_DO178C : Boolean := True;
      end record;

      --  A single component of a software bill of materials (SBOM).
      --  The root project occupies index 1. Dependency components reference
      --  their parent by vector index (0 = direct dependency of the root).
      --  HLR-SBOM: SBOM component record
      type Component_Info is record
         Ref             : Path_Field;
         Ref_Len         : Natural := 0;
         Name            : Desc_Field;
         Name_Len        : Natural := 0;
         Version         : Desc_Field;
         Version_Len     : Natural := 0;
         License         : Desc_Field;
         License_Len     : Natural := 0;
         PURL            : Path_Field;
         PURL_Len        : Natural := 0;
         Description     : Path_Field;
         Description_Len : Natural := 0;
         Language        : Desc_Field;
         Language_Len    : Natural := 0;
         --  Source-code repository or project website of the component, when
         --  known. The manifest parser fills it from the Alire release
         --  metadata (alire.lock `website` / `origin` URL or the local index
         --  via `alr show`). The dashboard links a dependency to this URL
         --  instead of guessing from the PURL, so no garbage links are
         --  produced. Empty when the source cannot be resolved.
         Website         : Path_Field;
         Website_Len     : Natural := 0;
         Kind            : Component_Kind := Dependency_Component;
         Parent          : Natural := 0;
         From_GPR        : Boolean := False;
         Scope           : Component_Scope := Scope_Transitive;
         Scope_Flags     : Dependency_Scope_Flags;
      end record;

      package Component_Vectors is new
        Ada.Containers.Vectors (Positive, Component_Info);

      --  SPARK coverage of one Ada source unit (one package, keyed by the
      --  base name of its source files). Three metrics are recorded per
      --  unit, each with its own numerator and denominator:
      --
      --    Stmts_Total / Stmts_Proved   statement coverage (executable
      --                                 statements in the unit's body)
      --    Subs_Total / Subs_Proved     subprogram coverage (subprograms
      --                                 gnatprove considered in the unit)
      --    Checks_Total / Checks_Proved VC coverage (checks the prover
      --                                 reported, passed or not)
      --
      --  A unit gnatprove never reported on holds the zero values, so the
      --  Not_Covered count is always derived (see Adacovex.Spark_Coverage)
      --  and never a stored total that can drift from its parts.
      --  HLR-SPARK: SPARK coverage metrics
      type Spark_Coverage_Unit is record
         Name              : Name_Field;
         Name_Len          : Natural := 0;
         Folder            : Path_Field;
         Folder_Len        : Natural := 0;
         File              : Path_Field;
         File_Len          : Natural := 0;
         Stmts_Total       : Natural := 0;
         Stmts_Proved      : Natural := 0;
         --  Statements in a unit gnatprove never reported on.
         --  They are neither proved nor off: the prover never
         --  looked at them, so they are counted separately and
         --  never folded into an off class.
         Stmts_Not_Covered : Natural := 0;
         Subs_Total        : Natural := 0;
         Subs_Proved       : Natural := 0;
         Checks_Total      : Natural := 0;
         Checks_Proved     : Natural := 0;
         --  Proof warnings the prover reported for this unit (not
         --  verification conditions, so never counted in the VC
         --  metric).
         Warnings          : Natural := 0;
         --  Subprograms in a unit gnatprove never reported on. It is
         --  derived (the body's declared subprograms for such a unit),
         --  never a stored total that can drift from its parts.
         Not_Covered_Subs  : Natural := 0;
         Off_Irreducible   : Natural := 0;
         Off_IO_Bound      : Natural := 0;
         Off_Work_Queue    : Natural := 0;
         --  Subprogram headers seen in the unit's body. When the unit
         --  was not part of the gnatprove run (In_Proof_Run is False)
         --  this is the count the prover never looked at, so it is the
         --  unit's not-covered subprogram count.
         Body_Subs         : Natural := 0;
         --  Whether the unit appeared in the gnatprove run at all. A unit
         --  that did not is never reported as proved and never folded
         --  into an off class.
         In_Proof_Run      : Boolean := False;
      end record;

      package Spark_Coverage_Vectors is new
        Ada.Containers.Vectors (Positive, Spark_Coverage_Unit);

      --  One named SPARK entity as gnatprove reports it: the qualified
      --  Ada name, and (for a skipped entity) the off class this report
      --  derived for it. A proved entity is recorded with Off_None.
      type Spark_Entity_Rec is record
         Name     : Name_Field;
         Name_Len : Natural := 0;
         Class    : Spark_Off_Class := Off_None;
      end record;

      package Spark_Entity_Vectors is new
        Ada.Containers.Vectors (Positive, Spark_Entity_Rec);

      --  One skipped entity as gnatprove reports it: its qualified Ada
      --  name, the source file that declares it, and the line the
      --  declaration starts on. The line is the entity's first line, so
      --  consecutive skip lines in the same file bound the source range
      --  that belongs to each unproved subprogram.
      type Spark_Skip_Rec is record
         Name     : Name_Field;
         Name_Len : Natural := 0;
         File     : Name_Field;
         File_Len : Natural := 0;
         Line     : Natural := 0;
      end record;

      package Spark_Skip_Vectors is new
        Ada.Containers.Vectors (Positive, Spark_Skip_Rec);

      --  SPARK coverage rolled up over a group of units (one file, one
      --  folder, or one Ada package). Every count is a sum, so a group
      --  percentage is always a ratio of sums and never a mean of its
      --  children.
      type Spark_Coverage_Group is record
         Key               : Path_Field;
         Key_Len           : Natural := 0;
         Stmts_Total       : Natural := 0;
         Stmts_Proved      : Natural := 0;
         Stmts_Not_Covered : Natural := 0;
         Subs_Total        : Natural := 0;
         Subs_Proved       : Natural := 0;
         Checks_Total      : Natural := 0;
         Checks_Proved     : Natural := 0;
         --  Proof warnings the prover reported (gnatprove SARIF
         --  results whose level is "warning"). They are not
         --  verification conditions, so they are never counted in
         --  the VC metric; the report lists them separately.
         Warnings          : Natural := 0;
         Off_Irreducible   : Natural := 0;
         Off_IO_Bound      : Natural := 0;
         Off_Work_Queue    : Natural := 0;
         Not_Covered_Subs  : Natural := 0;
         Unit_Ct           : Natural := 0;
      end record;

      package Spark_Group_Vectors is new
        Ada.Containers.Vectors (Positive, Spark_Coverage_Group);

      --  The whole-tree rollup: the group with the empty key.
      type Spark_Coverage_Totals is record
         Stmts_Total       : Natural := 0;
         Stmts_Proved      : Natural := 0;
         Stmts_Not_Covered : Natural := 0;
         Subs_Total        : Natural := 0;
         Subs_Proved       : Natural := 0;
         Checks_Total      : Natural := 0;
         Checks_Proved     : Natural := 0;
         Warnings          : Natural := 0;
         Off_Irreducible   : Natural := 0;
         Off_IO_Bound      : Natural := 0;
         Off_Work_Queue    : Natural := 0;
         Not_Covered_Subs  : Natural := 0;
         Unit_Ct           : Natural := 0;
      end record;
   end Implementation;

   --  Convert a SPARK_Level to its human-readable name.
   --  The function returns "Stone", "Bronze", "Silver", "Gold", or
   --  "Platinum".
   --  @return Human-readable SPARK level name.
   function To_String (L : SPARK_Level) return String
   with
     Post   =>
       To_String'Result = "Stone"
       or else To_String'Result = "Bronze"
       or else To_String'Result = "Silver"
       or else To_String'Result = "Gold"
       or else To_String'Result = "Platinum",
     Global => null;

   --  Convert a DAL_Level to its single-letter code ('A' through 'E').
   --  @return Single-letter DAL code.
   function To_String (L : DAL_Level) return String
   with Post => To_String'Result'Length = 1, Global => null;

   --  Parse a single-letter DAL code string into a DAL_Level.
   --  The function accepts both upper and lower case. It defaults to DAL_C
   --  on parse failure.
   --  @param S  Single-letter DAL code (A-E, case-insensitive).
   --  @return Converted DAL_Level (defaults to DAL_C on failure).
   function To_DAL (S : String) return DAL_Level
   with Global => null;

   --  Convert a Compliance_Standard to its human-readable name.
   --  @return "DO-178C", "ISO 26262", or "IEC 62304".
   function To_String (S : Compliance_Standard) return String
   with
     Post   =>
       To_String'Result = "DO-178C"
       or else To_String'Result = "ISO 26262"
       or else To_String'Result = "IEC 62304",
     Global => null;

   --  Parse a standard name into a Compliance_Standard. The function
   --  accepts "do178c"/"do-178c", "iso26262"/"iso-26262", and
   --  "iec62304"/"iec-62304" (case-insensitive). It defaults to DO_178C on
   --  parse failure.
   --  @param S  Standard name.
   --  @return Converted Compliance_Standard (defaults to DO_178C).
   function To_Standard (S : String) return Compliance_Standard
   with Global => null;

   --  Human-readable integrity-level label for a standard and a rigour tier.
   --  DO-178C keeps "DAL-A".."DAL-E". ISO 26262 maps A..E to "ASIL D",
   --  "ASIL C", "ASIL B", "ASIL A", "QM". IEC 62304 maps to "Class C",
   --  "Class B", "Class A", "No class", "No class".
   --  @param Standard  Compliance standard.
   --  @param Level  Rigour tier (reused DAL level).
   --  @return The standard-specific level label.
   function Standard_Level_Name
     (Standard : Compliance_Standard; Level : DAL_Level) return String
   with Post => Standard_Level_Name'Result'Length in 1 .. 8, Global => null;

   --  Parse an ASIL level into the shared rigour tier. ASIL A--D map to
   --  DAL_D--DAL_A (ASIL D is the most rigorous). QM maps to DAL_E (no
   --  safety effect). The function accepts "A".."D" and "QM"
   --  case-insensitively. It defaults to DAL_C (ASIL B) on parse failure.
   --  @param S  ASIL level (A-D or QM, case-insensitive).
   --  @return Shared rigour tier (defaults to DAL_C on failure).
   function To_ASIL (S : String) return DAL_Level
   with Global => null;

   --  Whether S is a valid ASIL level ("A".."D" or "QM", case-insensitive).
   --  @param S  Candidate ASIL level string.
   --  @return True when S names a valid ASIL level.
   function Is_Valid_ASIL (S : String) return Boolean
   with Global => null;

   --  Parse an IEC 62304 software safety class into the shared rigour tier.
   --  Class A--C map to DAL_C--DAL_A (Class C is the most rigorous). The
   --  function accepts "A".."C" case-insensitively. It defaults to DAL_C
   --  (Class A) on parse failure.
   --  @param S  Safety class (A-C, case-insensitive).
   --  @return Shared rigour tier (defaults to DAL_C on failure).
   function To_Class (S : String) return DAL_Level
   with Global => null;

   --  Whether S is a valid IEC 62304 safety class ("A".."C",
   --  case-insensitive).
   --  @param S  Candidate safety-class string.
   --  @return True when S names a valid safety class.
   function Is_Valid_Class (S : String) return Boolean
   with Global => null;

   --  Lowercase filename slug for a standard's badge file. The slug is
   --  "do178c", "iso26262", or "iec62304".
   --  @param S  Compliance standard.
   --  @return The standard's badge-file slug.
   function Standard_Slug (S : Compliance_Standard) return String
   with Post => Standard_Slug'Result'Length > 0, Global => null;

   --  Convert a Dashboard_Theme to its CLI value. The value is "system",
   --  "light", or "dark".
   --  @param T  Dashboard theme.
   --  @return The theme's CLI name.
   function To_String (T : Dashboard_Theme) return String
   with
     Post   =>
       To_String'Result = "system"
       or else To_String'Result = "light"
       or else To_String'Result = "dark",
     Global => null;

   --  Parse a dashboard theme name into a Dashboard_Theme. The function
   --  accepts "system", "light", and "dark" case-insensitively. It defaults
   --  to System_Theme on parse failure.
   --  @param S  Theme name.
   --  @return Converted Dashboard_Theme (defaults to System_Theme).
   function To_Theme (S : String) return Dashboard_Theme
   with Global => null;

   --  Whether S names a valid dashboard theme ("system", "light", or
   --  "dark", case-insensitive).
   --  @param S  Candidate theme string.
   --  @return True when S names a valid dashboard theme.
   function Is_Valid_Theme (S : String) return Boolean
   with Global => null;

   --  Convert a DAL_Status ("Achieved" or "Unmet") to its human-readable string.
   --  @return "Achieved" or "Unmet".
   function To_String (S : DAL_Status) return String
   with
     Post   =>
       To_String'Result = "Achieved" or else To_String'Result = "Unmet",
     Global => null;

   --  Convert a Test_Status ("Pass" or "Fail") to "PASS" or "FAIL".
   --  @return "PASS" or "FAIL".
   function To_String (S : Test_Status) return String
   with
     Post   => To_String'Result = "PASS" or else To_String'Result = "FAIL",
     Global => null;

   --  Convert a Spark_Metric_Kind to its CLI name: "statements",
   --  "subprograms", or "vcs". Every percentage in a SPARK-coverage report
   --  carries this label so a reader never has to guess which metric a
   --  number belongs to.
   --  @param M  Metric kind.
   --  @return The metric's CLI name.
   function To_String (M : Spark_Metric_Kind) return String
   with Global => null;

   --  Convert a Spark_Group_Kind to its CLI name: "file", "folder", or
   --  "package".
   --  @param G  Group kind.
   --  @return The group kind's CLI name.
   function To_String (G : Spark_Group_Kind) return String
   with Global => null;

   --  Convert a Spark_Off_Class to its report label: "none", "irreducible",
   --  "io-bound", "work-queue", or "not-covered".
   --  @param C  Off class.
   --  @return The class label.
   function To_String (C : Spark_Off_Class) return String
   with Global => null;

end Adacovex.Types;
