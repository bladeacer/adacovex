with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Adacovex.Cache;
with Adacovex.CPUs;
with Adacovex.Dir_Cache;

package body Adacovex.Parsers.Manifest is

   use type Types.Component_Kind;
   use type Types.Component_Scope;

   --  Small local name list used to collect GPR with-clause dependencies.
   type Name_Item is record
      Name : Types.Desc_Field;
      Len  : Natural := 0;
   end record;

   package Name_Vectors is new Ada.Containers.Vectors (Positive, Name_Item);

   --  One requirement line of a requirements*.txt: package name + optional
   --  pinned version ("requests==2.28.1" -> name "requests", version
   --  "2.28.1"). Used to register the project root's Python requirements as
   --  pypi-scope dependencies.
   type Req_Item is record
      Name : Types.Desc_Field;
      Len  : Natural := 0;
      Ver  : Types.Desc_Field;
      VLen : Natural := 0;
   end record;

   package Req_Vectors is new Ada.Containers.Vectors (Positive, Req_Item);

   --  Small local path list used to collect .gpr files in the project tree.
   type Path_Item is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;

   package Path_Vectors is new Ada.Containers.Vectors (Positive, Path_Item);

   --  One entry of a parsed Go vendor manifest: a module path and the
   --  version `go mod vendor` recorded for it. The whole vendor manifest is
   --  parsed once per vendor root and then looked up in memory, rather than
   --  rescanned from disk once per component.
   type Go_Module_Entry is record
      Path : Types.Desc_Field;
      PLen : Natural := 0;
      Ver  : Types.Desc_Field;
      VLen : Natural := 0;
   end record;

   package Go_Module_Vectors is new
     Ada.Containers.Vectors (Positive, Go_Module_Entry);

   --  Crate-name sets collected from the publishing manifest (alire.toml or
   --  the --manifest override) and the dev manifest (alire-dev.toml). Used
   --  to classify every resolved dependency into a Component_Scope. A name
   --  declared under a [[test-depends-on]] section of either manifest is
   --  classified Scope_Test (a test-only dependency).
   Base_Names : Name_Vectors.Vector;
   Dev_Names  : Name_Vectors.Vector;
   Test_Names : Name_Vectors.Vector;

   --  On-disk serialization for the resolved dependency graph. An
   --  unchanged manifest/lockfile/.gpr set is then served from the result
   --  cache without re-parsing (HLR-SBOM: dependency-graph caching).
   package Graph_Store is new
     Adacovex.Cache.Serialization
       (Types.Implementation.Component_Vectors.Vector);

   procedure Set_Field
     (Field : out Types.Desc_Field; Len : out Natural; S : String)
   is separate;

   procedure Set_Path
     (Field : out Types.Path_Field; Len : out Natural; S : String)
   is separate;

   --  Working set of the system-tool discovery pass. The scan is one
   --  procedure, but its steps (the directory walk, the per-file word scan,
   --  the version probes, the cache round-trip) live in their own separate
   --  bodies, so the state they share is held at package level. Every
   --  variable below is cleared at the start of Discover_System_Dev_Deps,
   --  so the pass has the same per-call lifetime the nested declarations
   --  had before the split.

   --  One directory pending the system-tool scan.
   type Scan_Dir_Entry is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;

   package Scan_Dir_Vectors is new
     Ada.Containers.Vectors (Positive, Scan_Dir_Entry);

   Scan_Stack : Scan_Dir_Vectors.Vector;

   --  Tool names the project's files reference (deduplicated).
   Referenced : Name_Vectors.Vector;

   --  One observed tool version: the "tool=version" pairs restored from a
   --  cache blob or produced by a fresh version probe.
   type Probe_Pair is record
      Name  : Types.Name_Field;
      NLen  : Natural := 0;
      Ver   : Types.Desc_Field;
      VLen  : Natural := 0;
      --  Identity digest of the binary the version was probed from
      --  (SHA-256 of the fingerprint image). Restored-from-cache probe
      --  entries are re-validated against the live binary: a mismatch
      --  re-probes. Length 0 = pre-fingerprint blob entry, which never
      --  validates.
      Fp    : Types.Desc_Field;
      FpLen : Natural := 0;
   end record;

   package Probe_Vectors is new Ada.Containers.Vectors (Positive, Probe_Pair);
   Probes : Probe_Vectors.Vector;

   --  Whether the referenced-tool set (and its probe results) came from
   --  the on-disk cache. Used to skip the PATH walk and version probes.
   From_Cache : Boolean := False;

   --  Whether a cache hit re-validated a probe and had to re-probe a tool
   --  whose installed binary no longer matches the cached fingerprint. The
   --  refreshed set must then be written back, or the stale blob survives
   --  and every later run re-probes the same tool again. An unchanged
   --  toolchain leaves this False and still stores nothing on a hit.
   Refreshed : Boolean := False;

   --  Cache key (and its image) for the miss-store below. Kept at package
   --  level so the store can run after the probe loop.
   Key_Img : String (1 .. 128) := (others => ' ');
   Key_Len : Natural := 0;

   --  Strip leading and trailing spaces. A string of only spaces becomes
   --  the empty string. The body stays in this file: a SPARK aspect
   --  cannot be applied to a separate body declaration, so a proved
   --  subprogram cannot be split out that way.
   --  @param S  String to trim (its bounds must be non-degenerate).
   --  @return The trimmed string.
   function Trim (S : String) return String
   with
     SPARK_Mode => On,
     Pre        => S'First >= 1 and S'Last < Natural'Last and S'Last >= 0
   is
      F, L : Natural;
   begin
      F := S'First;
      L := S'Last;
      while F <= L and then S (F) = ' ' loop
         pragma Loop_Invariant (F in S'First .. S'Last + 1);
         pragma Loop_Variant (Increases => F);
         F := F + 1;
      end loop;
      while L >= F and then S (L) = ' ' loop
         pragma Loop_Invariant (L in S'First .. S'Last);
         pragma Loop_Variant (Decreases => L);
         L := L - 1;
      end loop;
      if L < F then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   --  Whether S begins with the exact character sequence Pre. The
   --  precondition gives the function a contract. gnatprove analyses the
   --  function as a unit. gnatprove does not re-prove the body at every
   --  call site.
   --  @param S  String to test.
   --  @param Pre  Prefix to look for.
   --  @return True when Pre is a prefix of S.
   function Starts_With (S : String; Pre : String) return Boolean
   with SPARK_Mode => On, Pre => S'First >= 1 and S'Last < Natural'Last
   is
   begin
      if Pre'Length > S'Length then
         return False;
      end if;
      return S (S'First .. S'First + Pre'Length - 1) = Pre;
   end Starts_With;

   --  Extract the quoted value of "Key = "value"" from a line of TOML.
   --  Returns "" when the key is not present or not a quoted string.
   function Key_Value (Line : String; Key : String) return String is separate;

   --  Extract the first quoted string inside "Key = ["list"]" (project-files).
   function First_List_Value (Line : String; Key : String) return String
   is separate;

   --  Read root-project metadata from an Alire manifest (alire.toml / dev).
   procedure Read_Manifest
     (Manifest_Path    : String;
      Root_Name        : out Types.Desc_Field;
      Root_Name_Len    : out Natural;
      Root_Version     : out Types.Desc_Field;
      Root_Version_Len : out Natural;
      Root_License     : out Types.Desc_Field;
      Root_License_Len : out Natural;
      Root_Desc        : out Types.Path_Field;
      Root_Desc_Len    : out Natural;
      Root_Website     : out Types.Path_Field;
      Root_Website_Len : out Natural;
      Project_File     : out Types.Path_Field;
      Project_File_Len : out Natural;
      Success          : out Boolean)
   is separate;

   --  Parse a GNAT project file: extract the project name and with clauses.
   procedure Parse_GPR
     (GPR_Path  : String;
      Proj_Name : out Types.Desc_Field;
      Proj_Len  : out Natural;
      Deps      : in out Name_Vectors.Vector)
   is separate;

   --  Collect every .gpr file under Target_Dir (excluding obj, alire, and
   --  more).
   procedure Collect_GPR_Files
     (Target_Dir : String; Files : in out Path_Vectors.Vector)
   is separate;

   --  Locate the .gpr file for a crate name within the collected files.
   procedure Find_GPR
     (Files : Path_Vectors.Vector;
      Crate : String;
      Path  : out Types.Path_Field;
      Len   : out Natural)
   is separate;

   function Name_In_Graph
     (Graph : Types.Implementation.Component_Vectors.Vector; Name : String)
      return Boolean
   is separate;

   --  Append a crate name to a name vector unless already present.
   procedure Add_Dep_Name (Names : in out Name_Vectors.Vector; Name : String)
   is separate;

   --  Collect the crate names declared in a manifest's [[depends-on]] (or
   --  [depends-on]) section into Names, and the crate names declared under a
   --  [[test-depends-on]] (or [test-depends-on]) section into Test_Names.
   --  Missing files are ignored. A physical line longer than Max_Line
   --  clears the collected names. No partial set is kept.
   procedure Read_Manifest_Deps
     (Path       : String;
      Names      : in out Name_Vectors.Vector;
      Test_Names : in out Name_Vectors.Vector)
   is separate;

   --  Classify a dependency name into a Component_Scope from the collected
   --  manifest sets. A name declared under [[test-depends-on]] is test. A
   --  name in the publishing manifest is base. A name declared only in the
   --  dev manifest is dev. Any other name is transitive.
   function Classify_Scope (Name : String) return Types.Component_Scope
   is separate;

   --  Whether a dependency name carries a test label. The full name is
   --  checked first, then the last path segment after any '/' or ':'
   --  (which covers npm scope prefixes -- "@playwright/test" -- as well
   --  as Go module paths such as "github.com/stretchr/testify", maven
   --  groupId:artifactId names such as "org.testng:testng", and composer
   --  vendor/package names). A name (or its last segment) that starts or
   --  ends with the literal word "test" is test-labelled (for example
   --  @playwright/test, vitest, supertest, testify, testng). The
   --  vendored-component scan classifies such components Scope_Test, and
   --  the lockfile readers apply the same heuristic to lockfile-resolved
   --  names.
   --  @param Name  Dependency name (may be scoped, path-like, or
   --    colon-separated, e.g. "@playwright/test").
   --  @return True when the name (or its last segment) starts or ends
   --    with "test".
   function Is_Test_Named (Name : String) return Boolean is separate;

   --  Collect the dependency names a project manifest declares as
   --  test-only. Every supported ecosystem labels its test dependencies
   --  in its own way, and every label carries the literal word "test":
   --  package.json sections whose key contains "test" (for example
   --  "testDependencies"), Cargo's [dev-dependencies] section (and any
   --  section containing "test"), composer's require-dev, Gemfile
   --  `group :test` blocks, pom.xml <scope>test</scope> dependencies,
   --  pyproject.toml optional-dependencies extras containing "test" (plus
   --  Poetry test group sections), and Package.swift .testTarget
   --  dependencies. Ecosystems without a native test-only section
   --  (go.mod, requirements*.txt) rely on the name heuristic, which also
   --  applies to lockfile-resolved names (pnpm-lock.yaml,
   --  package-lock.json, yarn.lock, Cargo.lock). The first manifest
   --  found in Owner_Dir is used, in the same priority order as
   --  Read_Vendor_Manifest. Missing or unreadable files leave the set
   --  unchanged. A physical line longer than Max_Line stops the read;
   --  no partial set is kept.
   --  @param Owner_Dir  Directory holding the project manifest that owns a
   --    vendored directory (for example tests/e2e owns
   --    tests/e2e/node_modules).
   --  @param Test_Names  Collected test-labelled dependency names.
   procedure Collect_Owner_Test_Names
     (Owner_Dir : String; Test_Names : in out Name_Vectors.Vector)
   is separate;

   procedure Append_Dependency
     (Graph    : in out Types.Implementation.Component_Vectors.Vector;
      Name     : String;
      Version  : String;
      License  : String;
      Desc     : String;
      PURL     : String;
      Parent   : Natural;
      From_GPR : Boolean;
      Scope    : Types.Component_Scope;
      Language : String := "";
      Website  : String := "")
   is separate;

   --  Resolve a component's version, licence and website from its ecosystem
   --  registry CLI, table-driven across every supported ecosystem (npm,
   --  pnpm, cargo, go, alr). Each table row names the CLI tool, its
   --  subcommand, and -- per metadata field -- the registry key to query and
   --  how to parse the value from the command output. Adding an ecosystem
   --  is a one-row edit. Ecosystems with no reliable registry CLI carry an
   --  empty tool and resolve to "": the vendored-manifest scanner still reads
   --  any in-repo licence file.
   --
   --  This is a best-effort, online fallback. Have_Version and Have_License
   --  report what the offline manifest read already answered. A spawn is
   --  skipped when the row's table entry can add nothing the caller lacks,
   --  which is the whole cost of a registry call on a tree where the offline
   --  read is complete: a Go vendor tree with a modules.txt and licence files
   --  would otherwise spawn `go` once per component and discard every answer.
   --  Returns "" for a field when the tool is missing, the package is
   --  unknown, the field is absent, or the command fails.
   procedure Resolve_Ecosystem_Metadata
     (Target       : String;
      Ecosystem    : String;
      Name         : String;
      Have_Version : Boolean;
      Have_License : Boolean;
      License      : out Types.Desc_Field;
      Lic_Len      : out Natural;
      Version      : out Types.Desc_Field;
      Ver_Len      : out Natural;
      Website      : out Types.Path_Field;
      Web_Len      : out Natural)
   is separate;

   --  Register manifest-declared dependencies that no GPR with-clause or
   --  lockfile resolved (or fill in missing metadata on entries that were).
   --  These are base deps from the publishing manifest (alire.toml) and dev
   --  deps from alire-dev.toml. Append_Dependency adds a name-only
   --  "pkg:alire/<name>" purl when the crate is not already in the graph.
   --  For every manifest-declared crate, `alr show` supplies the licence and
   --  source repository URL from Alire's local index -- filling them onto a
   --  freshly appended entry or an existing lockfile/GPR one whose source
   --  could not otherwise be resolved. No garbage links are produced: a
   --  URL is only ever taken from the release metadata, never guessed.
   procedure Register_Manifest_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector;
      Base_Names : Name_Vectors.Vector;
      Dev_Names  : Name_Vectors.Vector)
   is separate;

   procedure Read_Alire_Lock
     (Lock_Path : String;
      Graph     : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  Resolve GPR with-clause dependencies into the graph. Deps already
   --  present in the graph are skipped. Transitive GPR dependencies are
   --  resolved by parsing the referenced .gpr file (if it lives in the
   --  project tree), up to a bounded depth to guard against cycles. A
   --  dependency with-claused only from a test project file (a .gpr under
   --  a tests/ test/ or t/ directory, or a test-named project such as
   --  test_runner.gpr) is classified Scope_Test.
   procedure Resolve_GPR_Deps
     (Graph         : in out Types.Implementation.Component_Vectors.Vector;
      GPR_Files     : Path_Vectors.Vector;
      Deps          : Name_Vectors.Vector;
      Parent        : Natural;
      Depth         : Natural;
      From_Test_GPR : Boolean := False)
   is separate;

   --  Language name for a source file, derived from its extension. The
   --  extension is the source of truth. A .py file is Python even when a
   --  Cargo.toml sits next to it. The manifest language only breaks ties.
   --  @param Name  File base name (for example "a.py").
   --  @return Language display name ("Python"), or "" for unknown.
   function Extension_Language (Name : String) return String is separate;

   --  Per-language file counters used to rank a directory's languages.
   type Lang_Item is record
      Name : String (1 .. 16);
      Len  : Natural := 0;
      Ct   : Natural := 0;
   end record;
   package Lang_Vectors is new Ada.Containers.Vectors (Positive, Lang_Item);

   --  Whether a directory holding the detected language counters already
   --  contains the given language name.
   function Has_Lang (Langs : Lang_Vectors.Vector; L : String) return Boolean
   is separate;

   --  Whether a directory base name denotes a vendored-code directory that
   --  adacovex treats as a scope=vendored dependency source.
   --  @param N  Directory base name.
   --  @return True for vendored directory names.
   function Is_Vendor_Dir_Name (N : String) return Boolean is separate;

   --  Whether to skip descending into a directory during a source walk:
   --  VCS metadata, the adacovex config dir, installer/build outputs, and
   --  Alire's own dependency cache never carry project source.
   function Skip_Walk_Dir (N : String) return Boolean is separate;

   --  Count the source files under Root by language, descending at most
   --  Max_Levels subdirectories (0 = Root's direct children only). Only
   --  file names are read (no content), so this is cheap. When Skip_Vend
   --  is True, vendored directories are not descended into -- used for the
   --  root project's own language so vendored code is never attributed to
   --  the owning project.
   procedure Detect_Languages
     (Root          : String;
      Max_Levels    : Natural;
      Langs         : in out Lang_Vectors.Vector;
      Skip_Vendored : Boolean := False)
   is separate;

   --  Rank a detected language counter vector. The primary language is
   --  first. The primary language is the ecosystem manifest's language (for
   --  example Rust for Cargo.toml). The remaining languages follow by file
   --  count descending. Ties follow by name ascending. Join up to 3 with
   --  " - ". Mixed-language sources list the top ~3 languages. This keeps
   --  "Ada; C; C++" style labels bounded.
   --  @param Langs  Detected language counters (must be sorted into rank).
   --  @param Primary  Ecosystem language, or "" to rank by file count only.
   --  @return Joined language summary (for example "Ada; C; C++").
   function Language_Summary
     (Langs : Lang_Vectors.Vector; Primary : String) return String
   is separate;

   --  Everything needed to turn a vendored directory into a graph component:
   --  ecosystem PURL kind, canonical name/version, and the ecosystem's
   --  primary language.
   type Vendor_Manifest is record
      Found            : Boolean := False;
      Name             : Types.Desc_Field;
      Name_Len         : Natural := 0;
      Version          : Types.Desc_Field;
      Version_Len      : Natural := 0;
      License          : Types.Desc_Field;
      License_Len      : Natural := 0;
      PURL_Kind        : String (1 .. 16);
      PURL_Kind_Len    : Natural := 0;
      Primary_Lang     : String (1 .. 16);
      Primary_Lang_Len : Natural := 0;
      --  The registry ecosystem token the resolver dispatches on. It is
      --  the PURL type except where the two differ: a Go component's PURL
      --  type is "golang" (the package-url specification) while the
      --  registry CLI is "go", so the two tokens are kept apart rather
      --  than forced to match.
      Eco              : String (1 .. 16);
      Eco_Len          : Natural := 0;
   end record;

   --  Read the first "<Key>" quoted value from a key=value or key:value
   --  file (TOML or JSON, quoted key or bare): locate Key followed by '='
   --  or ':', then the next double-quoted string. "" when absent.
   function File_Quoted_Value (Path : String; Key : String) return String
   is separate;

   --  Read the first "module <path>" line of a go.mod (the module path is
   --  the Go component's canonical name).
   function Go_Module_Path (Path : String) return String is separate;

   --  Parse a Go vendor manifest (vendor/modules.txt) into the
   --  module-to-version table, once per vendor root.
   procedure Read_Go_Modules
     (Path : String; Table : out Go_Module_Vectors.Vector)
   is separate;

   --  Version recorded for a module in a parsed vendor manifest, "" when the
   --  table does not list it.
   function Go_Module_Version
     (Table : Go_Module_Vectors.Vector; Module : String) return String
   is separate;

   --  SPDX identifier for the licence file that ships beside an ecosystem
   --  manifest, classified from the licence text. "" when no licence file
   --  is present or the text matches no known marker; a licence is never
   --  guessed.
   function License_Id (Dir : String) return String is separate;

   --  First "gem " entry of a Gemfile: name and cleaned version.
   procedure Gem_Entry
     (Path    : String;
      Name    : out String;
      NLen    : out Natural;
      Version : out String;
      VLen    : out Natural)
   is separate;

   --  First non-comment requirement line of a requirements*.txt:
   --  "requests==2.28.1" -> name "requests", version "2.28.1".
   procedure Req_Entry
     (Path    : String;
      Name    : out String;
      NLen    : out Natural;
      Version : out String;
      VLen    : out Natural)
   is separate;

   --  Collect every non-comment requirement line of a requirements*.txt
   --  into Reqs (package name + optional pinned version). An overlong
   --  physical line stops the read and keeps the entries collected so far.
   --  @param Path  Path of the requirements file.
   --  @param Reqs  Collected requirements (appended).
   procedure Collect_Req_Entries
     (Path : String; Reqs : in out Req_Vectors.Vector)
   is separate;

   --  Register the project root's Python requirements (requirements*.txt
   --  at Target_Dir) as dev-scope pypi dependencies of the root. Each
   --  requirement becomes a pkg:pypi/<name>[@<version>] component; the
   --  version, licence and website are resolved from the package registry
   --  (PyPI via `pip index versions`) when the requirements line pins no
   --  version or the registry answers. A missing registry or a failing
   --  resolve keeps the name-only entry -- no licence is ever guessed.
   procedure Register_Root_Python_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  First <Tag>...</Tag> occurrence on a single line of an XML file
   --  (pom.xml). Returns the inner text, "" when absent.
   function Xml_Tag_Value (Path : String; Tag : String) return String
   is separate;

   --  Probe Dir for the first recognised ecosystem manifest (in the defined
   --  priority order): package.json (npm), Cargo.toml (cargo), go.mod
   --  (golang), pyproject.toml (pypi), composer.json (composer), Gemfile
   --  (gem), pom.xml (maven), requirements*.txt (pypi), Package.swift
   --  (swift). Name and version come from the manifest when present.
   --  Modules is the parsed vendor manifest of the vendor root the
   --  component was found under, empty when there is none. The caller falls
   --  back to the directory name or "" otherwise.
   procedure Read_Vendor_Manifest
     (Dir     : String;
      Modules : Go_Module_Vectors.Vector;
      Info    : out Vendor_Manifest)
   is separate;

   --  Language summary of the source files under a directory. The primary
   --  (ecosystem) language is first when given. The top detected languages
   --  follow by file count. Join them with "; " (max 3 labels).
   --  @param Root  Directory tree to scan (file names only, no content).
   --  @param Max_Levels  Subdirectory depth to descend into.
   --  @param Primary_Kind  Ecosystem primary language or "".
   --  @return Language summary (for example "Ada; C; C++"), "" when nothing.
   function Language_Of_Dir
     (Root : String; Max_Levels : Natural; Primary_Kind : String := "")
      return String
   is separate;

   --  Add a component for every vendored package overlaid by a docstring
   --  patch under <target>/.adacovex/patches/. Add a component for every
   --  web asset under resources/ or assets/. Add a component for every
   --  source file under vendor/ (the classic Alire-era vendored roots).
   --  Each file becomes a scope=vendored component named after its base
   --  name. The language comes from the file extension. Such packages
   --  have no manifest entry and no .gpr of their own. They are recorded
   --  as Scope_Vendored dependencies of the root.
   procedure Discover_Vendored_Components
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  Language-agnostic vendored-component discovery. Walk the target tree
   --  (excluding VCS, build, and installer noise). Treat every directory
   --  whose base name is a known vendor directory as a vendored source.
   --  Scan it shallowly (max 2 levels):
   --    * A directory that carries an ecosystem manifest (package.json,
   --      Cargo.toml, go.mod, pyproject.toml, composer.json, Gemfile,
   --      pom.xml, Package.swift, requirements*.txt) becomes one
   --      Scope_Vendored component. The manifest names and versions it.
   --      Its ecosystem PURL is pkg:npm/... or pkg:cargo/... and more.
   --    * A directory that holds Ada sources (.ads/.adb) without a manifest
   --      becomes a Scope_Vendored Ada component. It is named after the
   --      directory (for example a hand-vendored Ada library under
   --      third_party/). npm scope containers (node_modules/@scope without
   --      a manifest) never become components; the scoped package below
   --      them does. pnpm store and shim dirs (.pnpm, .bin) are skipped
   --      entirely -- they are not packages.
   --  Every component carries its language or languages. The languages are
   --  detected from file extensions. The ecosystem language is first. The
   --  top 3 are used and mixed sources list the leading languages.
   procedure Discover_Generic_Vendored
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   type Tool_Category is
     (C_Build,     --  compile / test drivers (make, gprbuild, pytest)
      C_Lang,      --  language implementations & package managers (python3, cargo, go)
      C_VCS,       --  version control (git, hg, jj)
      C_Doc,       --  documentation tooling (pandoc, mandb, gnatdoc)
      C_CI,        --  CI / container / release plumbing (gh, docker, curl)
      C_Perf);     --  performance engineering (hyperfine, perf, strace)

   type Tool_Entry is record
      Name : String (1 .. 16);
      Len  : Natural := 0;
      Cat  : Tool_Category := C_Build;
   end record;

   --  Build a Tool_Entry from a string literal. The version-probe flag is
   --  deliberately NOT stored: Probe_Version infers it at run time by
   --  trying the standard chain ("--version", then "-v", then "version")
   --  and taking the first flag that yields a version token, so a tool
   --  that only understands a subcommand (go, fossil, git-lfs) needs no
   --  special-cased column here and a misconfigured entry cannot exist.
   --  The category is metadata only today (grouping the table by intent);
   --  a future probe policy can consult it.
   --  @param S  Tool name (lowercase, for example "python3").
   --  @param C  Category (default C_Build).
   --  @return The Tool_Entry holding S.
   function Make_Tool
     (S : String; C : Tool_Category := C_Build) return Tool_Entry
   is separate;

   --  The curated system-tool table. This is a DENY-BY-DEFAULT list, not
   --  a registry of everything on PATH: a tool lands in the SBOM only when
   --  (a) its exact lowercase name appears as a whole word in one of the
   --  project's dev-facing build files (see Should_Scan), and (b) it is
   --  installed on PATH. Whole-word matching keeps "makefile" from
   --  matching "make" and "python3" from matching "python"; scoping the
   --  scan to build files keeps prose and source identifiers from
   --  registering phantom tools. Add an entry when a project's build
   --  files reference the tool by name -- keep the list alphabetical
   --  within each category.
   System_Tools : constant array (1 .. 63) of Tool_Entry :=
     (
      --  Build / test drivers.
      Make_Tool ("alr"),
      Make_Tool ("cmake"),
      Make_Tool ("gprbuild"),
      Make_Tool ("gprclean"),
      Make_Tool ("gprinstall"),
      Make_Tool ("gnatbind"),
      Make_Tool ("gnatlink"),
      Make_Tool ("gnatmake"),
      Make_Tool ("gnatprep"),
      Make_Tool ("gradle"),
      Make_Tool ("make"),
      Make_Tool ("mvn"),
      Make_Tool ("ninja"),
      Make_Tool ("pytest", C_Build),
      --  Languages & package managers.
      Make_Tool ("alire", C_Lang),
      Make_Tool ("ada", C_Lang),
      Make_Tool ("cargo-hack", C_Lang),
      Make_Tool ("cargo-watch", C_Lang),
      Make_Tool ("cargo", C_Lang),
      Make_Tool ("clang", C_Lang),
      Make_Tool ("dotnet", C_Lang),
      Make_Tool ("gcc", C_Lang),
      Make_Tool ("g++", C_Lang),
      Make_Tool ("gnat", C_Lang),
      Make_Tool ("gnatformat", C_Lang),
      Make_Tool ("gnatls", C_Lang),
      Make_Tool ("gnatprove", C_Lang),
      Make_Tool ("gnatpp", C_Lang),
      Make_Tool ("go", C_Lang),
      Make_Tool ("javac", C_Lang),
      Make_Tool ("node", C_Lang),
      Make_Tool ("npm", C_Lang),
      Make_Tool ("pip", C_Lang),
      Make_Tool ("pip3", C_Lang),
      Make_Tool ("pnpm", C_Lang),
      Make_Tool ("python3", C_Lang),
      Make_Tool ("python", C_Lang),
      Make_Tool ("rst2md", C_Lang),
      Make_Tool ("ruby", C_Lang),
      Make_Tool ("rustc", C_Lang),
      Make_Tool ("rustup", C_Lang),
      Make_Tool ("sass", C_Lang),
      Make_Tool ("scss", C_Lang),
      Make_Tool ("tsc", C_Lang),
      Make_Tool ("yarn", C_Lang),
      --  Version control.
      Make_Tool ("fossil", C_VCS),
      Make_Tool ("git-lfs", C_VCS),
      Make_Tool ("git", C_VCS),
      Make_Tool ("hg", C_VCS),
      Make_Tool ("jj", C_VCS),
      Make_Tool ("svn", C_VCS),
      --  Documentation.
      Make_Tool ("gnatdoc", C_Doc),
      Make_Tool ("mandb", C_Doc),
      Make_Tool ("pandoc", C_Doc),
      --  CI / container / release plumbing.
      Make_Tool ("bash", C_CI),
      Make_Tool ("curl", C_CI),
      Make_Tool ("docker", C_CI),
      Make_Tool ("gh", C_CI),
      Make_Tool ("podman", C_CI),
      Make_Tool ("wget", C_CI),
      --  Performance engineering: a Makefile or CI recipe that benchmarks
      --  or traces with these depends on them as dev-scope system
      --  components; the SBOM says so.
      Make_Tool ("hyperfine", C_Perf),
      Make_Tool ("perf", C_Perf),
      Make_Tool ("strace", C_Perf));

   --  Probe a tool's version by running "<Tool> <Flag>" and extracting the
   --  first whitespace-separated token that contains a digit from the
   --  captured output (for example "2.55.0" from "git version 2.55.0",
   --  "4.4.1" from "GNU Make 4.4.1", "1.21.5" from "go version go1.21.5").
   --  Returns "" when the tool is missing, when every probe fails, or when
   --  no digit token is found. The configured flag is tried first; when it
   --  fails the probe falls back through "--version", "-v", and "version"
   --  and takes the first successful run.
   --  @param Tool  Executable name (must be on PATH).
   --  @param Flag  Version-probe flag or subcommand (first choice).
   --  @return The extracted version string, or "".
   function Probe_Version (Tool : String; Flag : String) return String
   is separate;

   --  Record a probe result for a referenced tool (deduplicated).
   procedure Add_Probe (Name : String; Version : String) is separate;

   --  Record a probe result and the identity digest of the binary it was
   --  probed from, so a later cache hit can re-validate the entry.
   procedure Add_Probe_Fp
     (Name : String; Version : String; Fp_Digest : String) is separate;

   --  SHA-256 of the fingerprint of the installed tool binary, "" when the
   --  tool is not on PATH.
   function Tool_Fp_Digest (Name : String) return String is separate;

   --  Queue a directory for the system-tool scan. A path longer than
   --  Types.Max_Path is dropped: the walk can never reach it.
   procedure Push_Scan_Dir (Dir : String) is separate;

   --  Whether to scan a file for tool references. Only dev-facing build
   --  files are scanned: Makefile variants (by name), build manifests
   --  (package.json, Cargo.toml, go.mod, pyproject.toml, ...), shell
   --  scripts, GNAT project files, and CI workflows. Source files are
   --  deliberately excluded -- scanning them produces false positives
   --  (identifiers like "ada", "go", "make" collide with tool names) and
   --  they never invoke build tools by name.
   function Should_Scan (Name : String) return Boolean is separate;

   --  Record Tool as referenced by the project's files.
   procedure Note_Tool (Tool : Tool_Entry) is separate;

   --  Whether C bounds a tool-name word in a line. A word is a maximal
   --  run of lowercase letters, digits, underscore, and hyphen
   --  ([a-z0-9_-]). Uppercase letters do not start or continue a word,
   --  so "Makefile" and "MAKE" never match the lowercase tool "make".
   function Is_Word_Char (C : Character) return Boolean is separate;

   --  When the word at Line (W_First .. W_Last) names one of the curated
   --  system tools, record it via Note_Tool. The match is
   --  case-sensitive. Only words whose length equals a tool name are
   --  compared, so a line is scored once per word instead of once per
   --  tool. "make" matches in "make build". "make" does not match in
   --  "Makefile" (capital M), "makefile", or "makefiles". "python"
   --  does not match inside "python3".
   --  @param Line  Line of text to search.
   --  @param W_First  First index of the word in Line.
   --  @param W_Last  Last index of the word in Line.
   procedure Note_If_Tool
     (Line : String; W_First : Natural; W_Last : Natural) is separate;

   --  Record every system tool that Line references as a whole word.
   --  The line is walked once, extracting maximal [a-z0-9_-] words, and
   --  each word is compared against the tool table by length first.
   --  This replaces a per-tool substring scan (60 tools x line length)
   --  with a per-word scan (a few words x 60 length checks), which was
   --  the dominant CPU cost of the SBOM system-dev-dependency discovery
   --  on every run.
   --  @param Line  Line of text to search.
   procedure Note_Referenced_Tools (Line : String) is separate;

   --  Scan one dev-facing build file for every known system tool. An
   --  overlong physical line stops the scan of that file, so a truncated
   --  file never yields a partial tool set.
   --  @param Path  Path of the file to read.
   procedure Scan_File (Path : String) is separate;

   --  Source-tree content hash used by Tools_Key. Walks the same
   --  directories and files that Discover_System_Dev_Deps scans and
   --  combines per-file digests. This is what makes the tool-set cache
   --  sound: a file edit that adds or removes a tool reference changes
   --  the hash, so the next run re-scans instead of serving a stale
   --  set. The directory-exclusion list matches the main walk exactly.
   --  @param Dir  Project root directory to hash.
   --  @return SHA-256 of the hashed dev-facing files, "" when none.
   function Source_Tree_Hash (Dir : String) return String is separate;

   --  Input key for the referenced-tools cache. It combines the same
   --  content hashes that Graph_Key uses (manifest, dev manifest, lock,
   --  vendored hash, language summary, GPR files) with the source-tree
   --  content hash. The system-tool reference scan reads the same
   --  project files, so an unchanged project has an unchanged key and the
   --  cached set is served without re-walking the tree or re-reading a
   --  file.
   --  @param Target_Dir  Project root directory.
   --  @return "tools:" + SHA-256 digest, or "" when inputs are unhashable.
   function Tools_Key (Target_Dir : String) return String is separate;

   --  Whether the project root holds a Makefile variant (which implies
   --  make even when no recipe spells out the driver by name).
   --  @param Target_Dir  Project root directory.
   --  @return True when a Makefile, makefile, or GNUmakefile exists.
   function Has_Makefile (Target_Dir : String) return Boolean is separate;

   --  Serialize the referenced-tool set and its probe results to a
   --  cache blob. Format: comma-separated tool names, then a '|'
   --  separator, then comma-separated "name=version@digest" probe pairs
   --  (both bounded by the 8192-char blob). The probe section lets a cache
   --  hit skip re-running version probes and PATH lookups.
   --  @return The blob text for Probes and Referenced.
   function Serialize_Set return String is separate;

   --  Deserialize a cache blob into Referenced and Probes. A blob written
   --  before the fingerprinted probe format carries names only; every other
   --  section shape is parsed defensively and a malformed pair is skipped.
   --  @param Blob  The stored blob text.
   procedure Deserialize_Set (Blob : String) is separate;

   --  Discover system-tool dev dependencies referenced by the project.
   --  Walk the project tree and read only dev-facing build files: Makefile
   --  variants, shell scripts, GNAT project files, CI workflows, and the
   --  project's build manifests (Cargo.toml, go.mod, pyproject.toml,
   --  package.json, ...). Register every known system tool that those files
   --  reference and that is actually installed on PATH. Register it as a
   --  dev-scope dependency of the root. A Makefile at the project root
   --  implies make. This applies even when no recipe spells out the driver
   --  by name.
   --
   --  Source files (.ads/.adb/.c/.go/.rs/.js/.ts/...) are NOT scanned. They
   --  are not tool invocations: scanning them is a source of false positives
   --  because identifiers and keywords collide with tool names (every Ada
   --  source contains the word "ada", which matches the curated "ada" tool;
   --  a Rust file contains "go"; a C file contains "make"). The detection is
   --  therefore scoped to files that actually drive a build, never to source
   --  text. Docstrings (.md prose) are also skipped: prose is not tool
   --  interaction and words like "make" are common in it.
   procedure Discover_System_Dev_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  Fingerprint of everything that contributes vendored components to
   --  the graph. Every file under the classic vendored roots
   --  (<target>/.adacovex/patches, resources, vendor, assets) is included.
   --  Every file under the language-agnostic vendored directories that
   --  Discover_Generic_Vendored discovers is included (deps, third_party,
   --  node_modules, and more, hashed to depth 3). Adding, removing, or
   --  editing any of those files changes the digest. The cached graph is
   --  then invalidated correctly.
   --  Returns "" when no vendored input exists.
   --  @param Target_Dir  Project root directory.
   --  @return SHA256 of the vendored inputs, or "" when none exist.
   function Vendored_Hash (Target_Dir : String) return String is separate;

   --  Combined content hash of everything that shapes the dependency graph.
   --  The publishing manifest, the dev manifest, and the alire.lock are
   --  included. Every .gpr file collected from the project tree is
   --  included. The vendored directories (classic roots and language-
   --  agnostic vendor dirs) are included. The root project's detected
   --  language mix is included. It is a cheap probe of the source tree's
   --  file-name distribution. A source-language change then invalidates
   --  the cached graph too. Returns "" when no input could be hashed.
   --  Nothing is cached in that case.
   --  @param Target_Dir  Project root directory (for alire-dev.toml,
   --    alire/alire.lock, the vendored dirs, and the root language probe,
   --    which live beside or under it).
   --  @param Manifest_Path  Path to the Alire manifest (can be an override).
   --  @param GPR_Files  Every .gpr file found under the target tree.
   --  @return "graph:" + SHA-256 digest, or "" when inputs are unhashable.
   function Graph_Key
     (Target_Dir    : String;
      Manifest_Path : String;
      GPR_Files     : Path_Vectors.Vector) return String
   is separate;

   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean;
      Use_Cache     : Boolean := False)
   is separate;

end Adacovex.Parsers.Manifest;