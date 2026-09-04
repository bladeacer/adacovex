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
   --  "2.28.1").  Used to register the project root's Python requirements as
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

   --  Crate-name sets collected from the publishing manifest (alire.toml or
   --  the --manifest override) and the dev manifest (alire-dev.toml).  Used
   --  to classify every resolved dependency into a Component_Scope.  A name
   --  declared under a [[test-depends-on]] section of either manifest is
   --  classified Scope_Test (a test-only dependency).
   Base_Names : Name_Vectors.Vector;
   Dev_Names  : Name_Vectors.Vector;
   Test_Names : Name_Vectors.Vector;

   --  On-disk serialization for the resolved dependency graph.  An
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

   --  Whether S begins with the exact character sequence Pre.  The
   --  precondition gives the function a contract.  gnatprove analyses the
   --  function as a unit.  gnatprove does not re-prove the body at every
   --  call site.
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
   --  Missing files are ignored.  A physical line longer than Max_Line
   --  clears the collected names.  No partial set is kept.
   procedure Read_Manifest_Deps
     (Path       : String;
      Names      : in out Name_Vectors.Vector;
      Test_Names : in out Name_Vectors.Vector)
   is separate;

   --  Classify a dependency name into a Component_Scope from the collected
   --  manifest sets.  A name declared under [[test-depends-on]] is test.  A
   --  name in the publishing manifest is base.  A name declared only in the
   --  dev manifest is dev.  Any other name is transitive.
   function Classify_Scope (Name : String) return Types.Component_Scope
   is separate;

   --  Whether a dependency name carries a test label.  The full name is
   --  checked first, then the last path segment after any '/' or ':'
   --  (which covers npm scope prefixes -- "@playwright/test" -- as well
   --  as Go module paths such as "github.com/stretchr/testify", maven
   --  groupId:artifactId names such as "org.testng:testng", and composer
   --  vendor/package names).  A name (or its last segment) that starts or
   --  ends with the literal word "test" is test-labelled (for example
   --  @playwright/test, vitest, supertest, testify, testng).  The
   --  vendored-component scan classifies such components Scope_Test, and
   --  the lockfile readers apply the same heuristic to lockfile-resolved
   --  names.
   --  @param Name  Dependency name (may be scoped, path-like, or
   --    colon-separated, e.g. "@playwright/test").
   --  @return True when the name (or its last segment) starts or ends
   --    with "test".
   function Is_Test_Named (Name : String) return Boolean is separate;

   --  Collect the dependency names a project manifest declares as
   --  test-only.  Every supported ecosystem labels its test dependencies
   --  in its own way, and every label carries the literal word "test":
   --  package.json sections whose key contains "test" (for example
   --  "testDependencies"), Cargo's [dev-dependencies] section (and any
   --  section containing "test"), composer's require-dev, Gemfile
   --  `group :test` blocks, pom.xml <scope>test</scope> dependencies,
   --  pyproject.toml optional-dependencies extras containing "test" (plus
   --  Poetry test group sections), and Package.swift .testTarget
   --  dependencies.  Ecosystems without a native test-only section
   --  (go.mod, requirements*.txt) rely on the name heuristic, which also
   --  applies to lockfile-resolved names (pnpm-lock.yaml,
   --  package-lock.json, yarn.lock, Cargo.lock).  The first manifest
   --  found in Owner_Dir is used, in the same priority order as
   --  Read_Vendor_Manifest.  Missing or unreadable files leave the set
   --  unchanged.  A physical line longer than Max_Line stops the read;
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
   --  pnpm, cargo, go, alr).  Each table row names the CLI tool, its
   --  subcommand, and -- per metadata field -- the registry key to query and
   --  how to parse the value from the command output.  Adding an ecosystem
   --  is a one-row edit.  Ecosystems with no reliable registry CLI carry an
   --  empty tool and resolve to "": the vendored-manifest scanner still reads
   --  any in-repo licence file.  This is a best-effort, online fallback used
   --  only when the offline manifest read finds nothing (for the licence) or
   --  to enrich with registry version and website.  Returns "" for a field
   --  when the tool is missing, the package is unknown, the field is absent,
   --  or the command fails.
   procedure Resolve_Ecosystem_Metadata
     (Target    : String;
      Ecosystem : String;
      Name      : String;
      License   : out Types.Desc_Field;
      Lic_Len   : out Natural;
      Version   : out Types.Desc_Field;
      Ver_Len   : out Natural;
      Website   : out Types.Path_Field;
      Web_Len   : out Natural)
   is separate;

   --  Register manifest-declared dependencies that no GPR with-clause or
   --  lockfile resolved (or fill in missing metadata on entries that were).
   --  These are base deps from the publishing manifest (alire.toml) and dev
   --  deps from alire-dev.toml.  Append_Dependency adds a name-only
   --  "pkg:alire/<name>" purl when the crate is not already in the graph.
   --  For every manifest-declared crate, `alr show` supplies the licence and
   --  source repository URL from Alire's local index -- filling them onto a
   --  freshly appended entry or an existing lockfile/GPR one whose source
   --  could not otherwise be resolved.  No garbage links are produced: a
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

   --  Resolve GPR with-clause dependencies into the graph.  Deps already
   --  present in the graph are skipped.  Transitive GPR dependencies are
   --  resolved by parsing the referenced .gpr file (if it lives in the
   --  project tree), up to a bounded depth to guard against cycles.  A
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

   --  Language name for a source file, derived from its extension.  The
   --  extension is the source of truth.  A .py file is Python even when a
   --  Cargo.toml sits next to it.  The manifest language only breaks ties.
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
   --  Max_Levels subdirectories (0 = Root's direct children only).  Only
   --  file names are read (no content), so this is cheap.  When Skip_Vend
   --  is True, vendored directories are not descended into -- used for the
   --  root project's own language so vendored code is never attributed to
   --  the owning project.
   procedure Detect_Languages
     (Root          : String;
      Max_Levels    : Natural;
      Langs         : in out Lang_Vectors.Vector;
      Skip_Vendored : Boolean := False)
   is separate;

   --  Rank a detected language counter vector.  The primary language is
   --  first.  The primary language is the ecosystem manifest's language (for
   --  example Rust for Cargo.toml).  The remaining languages follow by file
   --  count descending.  Ties follow by name ascending.  Join up to 3 with
   --  " - ".  Mixed-language sources list the top ~3 languages.  This keeps
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
   end record;

   --  Read the first "<Key>" quoted value from a key=value or key:value
   --  file (TOML or JSON, quoted key or bare): locate Key followed by '='
   --  or ':', then the next double-quoted string.  "" when absent.
   function File_Quoted_Value (Path : String; Key : String) return String
   is separate;

   --  Read the first "module <path>" line of a go.mod (the module path is
   --  the Go component's canonical name).
   function Go_Module_Path (Path : String) return String is separate;

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
   --  into Reqs (package name + optional pinned version).  An overlong
   --  physical line stops the read and keeps the entries collected so far.
   --  @param Path  Path of the requirements file.
   --  @param Reqs  Collected requirements (appended).
   procedure Collect_Req_Entries
     (Path : String; Reqs : in out Req_Vectors.Vector)
   is separate;

   --  Register the project root's Python requirements (requirements*.txt
   --  at Target_Dir) as dev-scope pypi dependencies of the root.  Each
   --  requirement becomes a pkg:pypi/<name>[@<version>] component; the
   --  version, licence and website are resolved from the package registry
   --  (PyPI via `pip index versions`) when the requirements line pins no
   --  version or the registry answers.  A missing registry or a failing
   --  resolve keeps the name-only entry -- no licence is ever guessed.
   procedure Register_Root_Python_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  First <Tag>...</Tag> occurrence on a single line of an XML file
   --  (pom.xml).  Returns the inner text, "" when absent.
   function Xml_Tag_Value (Path : String; Tag : String) return String
   is separate;

   --  Probe Dir for the first recognised ecosystem manifest (in the defined
   --  priority order): package.json (npm), Cargo.toml (cargo), go.mod
   --  (golang), pyproject.toml (pypi), composer.json (composer), Gemfile
   --  (gem), pom.xml (maven), requirements*.txt (pypi), Package.swift
   --  (swift).  Name and version come from the manifest when present.  The
   --  caller falls back to the directory name or "" otherwise.
   procedure Read_Vendor_Manifest (Dir : String; Info : out Vendor_Manifest)
   is separate;

   --  Language summary of the source files under a directory.  The primary
   --  (ecosystem) language is first when given.  The top detected languages
   --  follow by file count.  Join them with "; " (max 3 labels).
   --  @param Root  Directory tree to scan (file names only, no content).
   --  @param Max_Levels  Subdirectory depth to descend into.
   --  @param Primary_Kind  Ecosystem primary language or "".
   --  @return Language summary (for example "Ada; C; C++"), "" when nothing.
   function Language_Of_Dir
     (Root : String; Max_Levels : Natural; Primary_Kind : String := "")
      return String
   is separate;

   --  Add a component for every vendored package overlaid by a docstring
   --  patch under <target>/.adacovex/patches/.  Add a component for every
   --  web asset under resources/ or assets/.  Add a component for every
   --  source file under vendor/ (the classic Alire-era vendored roots).
   --  Each file becomes a scope=vendored component named after its base
   --  name.  The language comes from the file extension.  Such packages
   --  have no manifest entry and no .gpr of their own.  They are recorded
   --  as Scope_Vendored dependencies of the root.
   procedure Discover_Vendored_Components
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is separate;

   --  Language-agnostic vendored-component discovery.  Walk the target tree
   --  (excluding VCS, build, and installer noise).  Treat every directory
   --  whose base name is a known vendor directory as a vendored source.
   --  Scan it shallowly (max 2 levels):
   --    * A directory that carries an ecosystem manifest (package.json,
   --      Cargo.toml, go.mod, pyproject.toml, composer.json, Gemfile,
   --      pom.xml, Package.swift, requirements*.txt) becomes one
   --      Scope_Vendored component.  The manifest names and versions it.
   --      Its ecosystem PURL is pkg:npm/... or pkg:cargo/... and more.
   --    * A directory that holds Ada sources (.ads/.adb) without a manifest
   --      becomes a Scope_Vendored Ada component.  It is named after the
   --      directory (for example a hand-vendored Ada library under
   --      third_party/).  npm scope containers (node_modules/@scope without
   --      a manifest) never become components; the scoped package below
   --      them does.  pnpm store and shim dirs (.pnpm, .bin) are skipped
   --      entirely -- they are not packages.
   --  Every component carries its language or languages.  The languages are
   --  detected from file extensions.  The ecosystem language is first.  The
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

   --  Build a Tool_Entry from a string literal.  The version-probe flag is
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

   --  The curated system-tool table.  This is a DENY-BY-DEFAULT list, not
   --  a registry of everything on PATH: a tool lands in the SBOM only when
   --  (a) its exact lowercase name appears as a whole word in one of the
   --  project's dev-facing build files (see Should_Scan), and (b) it is
   --  installed on PATH.  Whole-word matching keeps "makefile" from
   --  matching "make" and "python3" from matching "python"; scoping the
   --  scan to build files keeps prose and source identifiers from
   --  registering phantom tools.  Add an entry when a project's build
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
   --  no digit token is found.  The configured flag is tried first; when it
   --  fails the probe falls back through "--version", "-v", and "version"
   --  and takes the first successful run.
   --  @param Tool  Executable name (must be on PATH).
   --  @param Flag  Version-probe flag or subcommand (first choice).
   --  @return The extracted version string, or "".
   function Probe_Version (Tool : String; Flag : String) return String
   is separate;

   --  Discover system-tool dev dependencies referenced by the project.
   --  Walk the project tree and read only dev-facing build files: Makefile
   --  variants, shell scripts, GNAT project files, CI workflows, and the
   --  project's build manifests (Cargo.toml, go.mod, pyproject.toml,
   --  package.json, ...).  Register every known system tool that those files
   --  reference and that is actually installed on PATH.  Register it as a
   --  dev-scope dependency of the root.  A Makefile at the project root
   --  implies make.  This applies even when no recipe spells out the driver
   --  by name.
   --  Source files (.ads/.adb/.c/.go/.rs/.js/.ts/...) are NOT scanned.  They
   --  are not tool invocations: scanning them is a source of false positives
   --  because identifiers and keywords collide with tool names (every Ada
   --  source contains the word "ada", which matches the curated "ada" tool;
   --  a Rust file contains "go"; a C file contains "make").  The detection is
   --  therefore scoped to files that actually drive a build, never to source
   --  text.  Docstrings (.md prose) are also skipped: prose is not tool
   --  interaction and words like "make" are common in it.
   procedure Discover_System_Dev_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;

      --  Tool names the project's files reference (deduplicated).
      Referenced : Name_Vectors.Vector;

      --  "tool=version" pairs observed for the referenced tools.  Populated
      --  on a scan (from the version probe) or restored from the tools
      --  cache blob on a hit, so the SBOM does not need to re-run probes
      --  for an unchanged project.
      type Probe_Pair is record
         Name  : Types.Name_Field;
         NLen  : Natural := 0;
         Ver   : Types.Desc_Field;
         VLen  : Natural := 0;
         --  Identity digest of the binary the version was probed from
         --  (SHA-256 of the fingerprint image).  Restored-from-cache probe
         --  entries are re-validated against the live binary: a mismatch
         --  re-probes.  Length 0 = pre-fingerprint blob entry, which never
         --  validates.
         Fp    : Types.Desc_Field;
         FpLen : Natural := 0;
      end record;
      package Probe_Vectors is new
        Ada.Containers.Vectors (Positive, Probe_Pair);
      Probes : Probe_Vectors.Vector;

      --  Record a probe result for a referenced tool (deduplicated).
      --  Forward-declared so Deserialize_Set can call it.
      procedure Add_Probe (Name : String; Version : String);
      procedure Add_Probe (Name : String; Version : String) is
      begin
         if Name'Length = 0 then
            return;
         end if;
         for I in 1 .. Integer (Probes.Length) loop
            if Probes (I).NLen = Name'Length
              and then Probes (I).Name (1 .. Name'Length) = Name
            then
               return;
            end if;
         end loop;
         declare
            P : Probe_Pair;
         begin
            P.NLen := Name'Length;
            P.Name (1 .. Name'Length) := Name (Name'First .. Name'Last);
            P.VLen := Version'Length;
            P.Ver (1 .. Version'Length) :=
              Version (Version'First .. Version'Last);
            Probes.Append (P);
         end;
      end Add_Probe;

      procedure Add_Probe_Fp
        (Name : String; Version : String; Fp_Digest : String) is
      begin
         if Name'Length = 0 then
            return;
         end if;
         for I in 1 .. Integer (Probes.Length) loop
            if Probes (I).NLen = Name'Length
              and then Probes (I).Name (1 .. Name'Length) = Name
            then
               Probes (I).FpLen := Fp_Digest'Length;
               Probes (I).Fp (1 .. Fp_Digest'Length) := Fp_Digest;
               return;
            end if;
         end loop;
         declare
            P : Probe_Pair;
         begin
            P.NLen := Name'Length;
            P.Name (1 .. Name'Length) := Name (Name'First .. Name'Last);
            P.VLen := Version'Length;
            P.Ver (1 .. Version'Length) :=
              Version (Version'First .. Version'Last);
            P.FpLen := Fp_Digest'Length;
            P.Fp (1 .. Fp_Digest'Length) := Fp_Digest;
            Probes.Append (P);
         end;
      end Add_Probe_Fp;

      function Tool_Fp_Digest (Name : String) return String is
         Exe : GNAT.OS_Lib.String_Access :=
           GNAT.OS_Lib.Locate_Exec_On_Path (Name);
      begin
         if Exe = null then
            return "";
         end if;
         declare
            D : constant String :=
              Adacovex.Cache.Hash_String
                (Adacovex.Cache.Tool_Fingerprint (Exe.all));
         begin
            GNAT.OS_Lib.Free (Exe);
            return D;
         end;
      end Tool_Fp_Digest;

      procedure Push_Dir (Dir : String) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;

      --  Whether to scan a file for tool references.  Only dev-facing build
      --  files are scanned: Makefile variants (by name), build manifests
      --  (package.json, Cargo.toml, go.mod, pyproject.toml, ...), shell
      --  scripts, GNAT project files, and CI workflows.  Source files are
      --  deliberately excluded -- scanning them produces false positives
      --  (identifiers like "ada", "go", "make" collide with tool names) and
      --  they never invoke build tools by name.
      function Should_Scan (Name : String) return Boolean is
         Dot : Natural := 0;
      begin
         if Name = "makefile"
           or else Name = "Makefile"
           or else Name = "GNUmakefile"
         then
            return True;
         end if;
         if Name = "package.json"
           or else Name = "tsconfig.json"
           or else Name = "jsconfig.json"
           or else Name = "Cargo.toml"
           or else Name = "Cargo.lock"
           or else Name = "go.mod"
           or else Name = "go.sum"
           or else Name = "Gemfile"
           or else Name = "requirements.txt"
           or else Name = "pyproject.toml"
           or else Name = "pom.xml"
           or else Name = "build.gradle"
           or else Name = "build.gradle.kts"
           or else Name = "settings.gradle"
           or else Name = "settings.gradle.kts"
           or else Name = "*.csproj"
           or else Name = "*.sln"
           or else Name = "Makefile"
           or else Name = "makefile"
         then
            return True;
         end if;
         for I in reverse Name'Range loop
            if Name (I) = '.' then
               Dot := I;
               exit;
            end if;
         end loop;
         if Dot = 0 then
            return False;
         end if;
         declare
            Ext : constant String := Name (Dot .. Name'Last);
         begin
            return
              Ext = ".sh"
              or else Ext = ".gpr"
              or else Ext = ".yml"
              or else Ext = ".yaml"
              or else Ext = ".toml";
         end;
      end Should_Scan;

      --  Record Tool as referenced by the project's files.
      procedure Note_Tool (Tool : Tool_Entry) is
      begin
         Add_Dep_Name (Referenced, Tool.Name (1 .. Tool.Len));
      end Note_Tool;

      --  Serialize the referenced-tool set and its probe results to a
      --  cache blob.  Format: comma-separated tool names, then a ';'
      --  separator, then comma-separated "name=version" probe pairs (both
      --  bounded by the 8192-char blob).  The probe section lets a cache
      --  hit skip re-running version probes and PATH lookups.
      function Serialize_Set return String is
         S : String (1 .. 8192);
         L : Natural := 0;

         procedure Add (Txt : String) is
         begin
            if L + Txt'Length <= S'Last then
               S (L + 1 .. L + Txt'Length) := Txt;
               L := L + Txt'Length;
            end if;
         end Add;
      begin
         for I in 1 .. Integer (Referenced.Length) loop
            declare
               Nm : constant String :=
                 Referenced (I).Name (1 .. Referenced (I).Len);
            begin
               if L > 0 then
                  Add (",");
               end if;
               Add (Nm);
            end;
         end loop;
         Add ("|");
         for I in 1 .. Integer (Probes.Length) loop
            declare
               Nm : constant String := Probes (I).Name (1 .. Probes (I).NLen);
               Vr : constant String := Probes (I).Ver (1 .. Probes (I).VLen);
               Fd : constant String := Probes (I).Fp (1 .. Probes (I).FpLen);
            begin
               if L > 0 and then S (L) /= '|' then
                  Add (",");
               end if;
               Add (Nm);
               Add ("=");
               Add (Vr);
               --  Binary-identity digest so a cache hit can re-validate
               --  each probe against the installed binary.  Entries without
               --  one (never in a v2 blob) would fail validation on load.
               Add ("@");
               Add (Fd);
            end;
         end loop;
         return S (1 .. L);
      end Serialize_Set;

      --  Deserialize the cache blob into Referenced and Probes.
      procedure Deserialize_Set (Blob : String) is
         Sep   : Natural := 0;
         Start : Natural := Blob'First;

         procedure Add_Name (Nm : String) is
         begin
            if Nm'Length > 0 then
               Add_Dep_Name (Referenced, Nm);
            end if;
         end Add_Name;
      begin
         --  Split on the '|' separator: names before, probe pairs after.
         for I in Blob'First .. Blob'Last loop
            if Blob (I) = '|' then
               Sep := I;
               exit;
            end if;
         end loop;
         if Sep = 0 then
            --  Old-format blob (names only).
            Start := Blob'First;
            for I in Blob'First .. Blob'Last loop
               if Blob (I) = ',' then
                  Add_Name (Blob (Start .. I - 1));
                  Start := I + 1;
               end if;
            end loop;
            if Start <= Blob'Last then
               Add_Name (Blob (Start .. Blob'Last));
            end if;
            return;
         end if;

         --  Names section.
         Start := Blob'First;
         for I in Blob'First .. Sep - 1 loop
            if Blob (I) = ',' then
               Add_Name (Blob (Start .. I - 1));
               Start := I + 1;
            end if;
         end loop;
         if Start <= Sep - 1 then
            Add_Name (Blob (Start .. Sep - 1));
         end if;

         --  Probe section: parse "name=version@fpdigest" comma-separated
         --  pairs.  A pair without '@' (pre-fingerprint blob) keeps an
         --  empty digest, which never validates -- the tool re-probes.
         Start := Sep + 1;
         for I in Sep + 1 .. Blob'Last loop
            if Blob (I) = ',' then
               declare
                  Nm     : constant String := Blob (Start .. I - 1);
                  Eq     : Natural := 0;
                  At_Pos : Natural := 0;
               begin
                  for J in Nm'Range loop
                     if Nm (J) = '=' and then Eq = 0 then
                        Eq := J;
                     elsif Nm (J) = '@' then
                        At_Pos := J;
                        exit;
                     end if;
                  end loop;
                  if Eq > Nm'First then
                     if At_Pos > Eq + 1 then
                        Add_Probe_Fp
                          (Nm (Nm'First .. Eq - 1),
                           Nm (Eq + 1 .. At_Pos - 1),
                           Nm (At_Pos + 1 .. Nm'Last));
                     else
                        Add_Probe
                          (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
                     end if;
                  end if;
               end;
               Start := I + 1;
            end if;
         end loop;
         if Start <= Blob'Last then
            declare
               Nm     : constant String := Blob (Start .. Blob'Last);
               Eq     : Natural := 0;
               At_Pos : Natural := 0;
            begin
               for J in Nm'Range loop
                  if Nm (J) = '=' and then Eq = 0 then
                     Eq := J;
                  elsif Nm (J) = '@' then
                     At_Pos := J;
                     exit;
                  end if;
               end loop;
               if Eq > Nm'First then
                  if At_Pos > Eq + 1 then
                     Add_Probe_Fp
                       (Nm (Nm'First .. Eq - 1),
                        Nm (Eq + 1 .. At_Pos - 1),
                        Nm (At_Pos + 1 .. Nm'Last));
                  else
                     Add_Probe
                       (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
                  end if;
               end if;
            end;
         end if;
      end Deserialize_Set;

      --  Record a probe result for a referenced tool (deduplicated).

      --  Whether C bounds a tool-name word in a line.  A word is a maximal
      --  run of lowercase letters, digits, underscore, and hyphen
      --  ([a-z0-9_-]).  Uppercase letters do not start or continue a word,
      --  so "Makefile" and "MAKE" never match the lowercase tool "make".
      function Is_Word_Char (C : Character) return Boolean is
      begin
         return
           (C in 'a' .. 'z')
           or else (C in '0' .. '9')
           or else C = '_'
           or else C = '-';
      end Is_Word_Char;

      --  When the word at Line (W_First .. W_Last) names one of the curated
      --  system tools, record it via Note_Tool.  The match is
      --  case-sensitive.  Only words whose length equals a tool name are
      --  compared, so a line is scored once per word instead of once per
      --  tool.  "make" matches in "make build".  "make" does not match in
      --  "Makefile" (capital M), "makefile", or "makefiles".  "python"
      --  does not match inside "python3".
      --  @param Line  Line of text to search.
      --  @param W_First  First index of the word in Line.
      --  @param W_Last  Last index of the word in Line.
      procedure Note_If_Tool
        (Line : String; W_First : Natural; W_Last : Natural)
      is
         W_Len : constant Natural := W_Last - W_First + 1;
      begin
         for T in System_Tools'Range loop
            if System_Tools (T).Len = W_Len then
               declare
                  Is_Tool : Boolean := True;
               begin
                  for J in 1 .. W_Len loop
                     if Line (W_First + J - 1) /= System_Tools (T).Name (J)
                     then
                        Is_Tool := False;
                        exit;
                     end if;
                  end loop;
                  if Is_Tool then
                     Note_Tool (System_Tools (T));
                     return;
                  end if;
               end;
            end if;
         end loop;
      end Note_If_Tool;

      --  Record every system tool that Line references as a whole word.
      --  The line is walked once, extracting maximal [a-z0-9_-] words, and
      --  each word is compared against the tool table by length first.
      --  This replaces a per-tool substring scan (60 tools x line length)
      --  with a per-word scan (a few words x 60 length checks), which was
      --  the dominant CPU cost of the SBOM system-dev-dependency discovery
      --  on every run.
      --  @param Line  Line of text to search.
      procedure Note_Referenced_Tools (Line : String) is
         W_First : Natural := Line'First;
         W_Last  : Natural;
      begin
         if Line'Length < 2 then
            --  No tool name is one character long; a shorter line cannot
            --  reference any tool.
            return;
         end if;
         while W_First <= Line'Last loop
            --  Skip non-word characters (whitespace, quotes, punctuation).
            while W_First <= Line'Last
              and then not Is_Word_Char (Line (W_First))
            loop
               W_First := W_First + 1;
            end loop;
            exit when W_First > Line'Last;
            W_Last := W_First;
            while W_Last < Line'Last and then Is_Word_Char (Line (W_Last + 1))
            loop
               W_Last := W_Last + 1;
            end loop;
            Note_If_Tool (Line, W_First, W_Last);
            W_First := W_Last + 1;
         end loop;
      end Note_Referenced_Tools;

      --  Scan one file for every known system tool.
      procedure Scan_File (Path : String) is
         use Ada.Text_IO;
         F        : File_Type;
         Line     : String (1 .. Types.Max_Line);
         Last     : Natural;
         Overflow : Boolean;
         Line_Num : Natural := 0;
      begin
         begin
            Open (F, In_File, Path);
         exception
            when others =>
               return;
         end;
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line.  Stop scanning this
               --  file.  A truncated file then never yields a partial tool
               --  set.
               Close (F);
               return;
            end if;
            if Ada.Strings.Fixed.Index
                 (Line (1 .. Last), "System_Tools : constant array")
              > 0
            then
               --  This file declares the curated tool table.  Every entry is
               --  a literal tool name by construction.  References found
               --  here can register every installed tool.  This happens
               --  regardless of whether the project actually uses the tool.
               Close (F);
               return;
            end if;
            Note_Referenced_Tools (Line (1 .. Last));
         end loop;
         Close (F);
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end Scan_File;

      --  Input key for the referenced-tools cache.  It combines the same
      --  content hashes that Graph_Key uses (manifest, dev manifest, lock,
      --  vendored hash, language summary, GPR files) with the source-tree
      --  content hash.  The system-tool reference scan reads the same
      --  project files, so an unchanged project has an unchanged key and the
      --  cached set is served without re-walking the tree or re-reading a
      --  file.
      --  Forward declaration so Tools_Key can call Source_Tree_Hash.
      function Source_Tree_Hash (Dir : String) return String;

      function Tools_Key (Target_Dir : String) return String is
         T    : constant String :=
           (if Target_Dir'Length > 1
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
         Comb : String (1 .. Types.Max_Path * 2);
         CLen : Natural := 0;
         procedure Add (S : String) is
         begin
            if S'Length > 0 and then CLen + S'Length <= Comb'Last then
               Comb (CLen + 1 .. CLen + S'Length) := S;
               CLen := CLen + S'Length;
            end if;
         end Add;
      begin
         --  Source_Tree_Hash covers every file the scan reads, so it alone
         --  determines the referenced-tool set.  The tool-table fingerprint
         --  invalidates the key when the System_Tools constant changes within
         --  a release.  Names and categories are folded in (the stored
         --  version-probe flag is gone: Probe_Version infers it at run
         --  time), so editing the table self-invalidates the cache -- no
         --  hand-maintained "|tools-vN|" salt bump to forget.  (The 1.33-era
         --  control of that same risk relied on a manually bumped salt; a
         --  forgotten bump served stale probe results within a release.)
         --  The "|probe-fb:...|" token also separates this namespace from
         --  the graph cache and the 1.27-era blob layout, while the flag
         --  chain stays part of the digest.
         Add (Source_Tree_Hash (T));
         for I in System_Tools'Range loop
            Add (System_Tools (I).Name (1 .. System_Tools (I).Len));
            Add (":");
            Add (Tool_Category'Image (System_Tools (I).Cat));
            Add (";");
         end loop;
         --  The probe fallback chain lives in Probe_Version -- fold its flag
         --  order in so reordering the fallbacks also busts the cache.
         Add ("|probe-fb:--version,-v,version|namespace-v4|");
         if CLen = 0 then
            return "";
         end if;
         return "tools:" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
      end Tools_Key;

      --  Source-tree content hash used by Tools_Key.  Walks the same
      --  directories and files that Discover_System_Dev_Deps scans and
      --  combines per-file digests.  This is what makes the tool-set cache
      --  sound: a file edit that adds or removes a tool reference changes
      --  the hash, so the next run re-scans instead of serving a stale
      --  set.  The directory-exclusion list matches the main walk exactly.
      function Source_Tree_Hash (Dir : String) return String is
         use Ada.Directories;
         type Dir_Entry is record
            Path : Types.Path_Field;
            Len  : Natural := 0;
         end record;
         package Hash_Dir_Stacks is new
           Ada.Containers.Vectors (Positive, Dir_Entry);
         Stack : Hash_Dir_Stacks.Vector;
         H     : String (1 .. Types.Max_Path * 8);
         HLen  : Natural := 0;

         procedure Add (S : String) is
         begin
            if S'Length > 0 and then HLen + S'Length <= H'Last then
               H (HLen + 1 .. HLen + S'Length) := S;
               HLen := HLen + S'Length;
            end if;
         end Add;
      begin
         if not Ada.Directories.Exists (Dir) then
            return "";
         end if;
         declare
            D : Dir_Entry;
         begin
            D.Len := Dir'Length;
            D.Path (1 .. D.Len) := Dir (Dir'First .. Dir'First + D.Len - 1);
            Stack.Append (D);
         end;
         while not Stack.Is_Empty loop
            declare
               C  : Dir_Entry := Stack.Last_Element;
               CP : String renames C.Path (1 .. C.Len);
               S  : Search_Type;
               E  : Directory_Entry_Type;
            begin
               Stack.Delete_Last;
               if not Ada.Directories.Exists (CP) then
                  null;
               else
                  --  Serve the shared snapshot (one enumeration per
                  --  directory per process across every walker) with a
                  --  direct-enumeration fallback for over-cap trees.
                  declare
                     Snap   : Adacovex.Dir_Cache.Dir_Entry_List;
                     SCt    : Natural;
                     STrunc : Boolean;
                     SOK    : Boolean;
                  begin
                     Adacovex.Dir_Cache.Snapshot (CP, Snap, SCt, STrunc, SOK);
                     if SOK and then not STrunc then
                        for SI in 1 .. SCt loop
                           declare
                              N    : constant String :=
                                Snap (SI).Name (1 .. Snap (SI).Name_Len);
                              NP   : constant String := CP & "/" & N;
                              Is_D : constant Boolean :=
                                Adacovex.Dir_Cache.Is_Directory
                                  (Snap (SI).Kind);
                           begin
                              if Is_D then
                                 if N /= ".git"
                                   and then N /= ".jj"
                                   and then N /= ".hg"
                                   and then N /= ".svn"
                                   and then N /= "obj"
                                   and then N /= "tests"
                                   and then N /= "config"
                                   and then N /= ".adacovex"
                                   and then N /= "alire"
                                   and then N /= "gnatprove"
                                   and then N /= "__pycache__"
                                   and then N /= "node_modules"
                                   and then N /= ".venv"
                                   and then N /= ".headroom"
                                   and then N /= ".lccst"
                                   and then N /= "_build"
                                 then
                                    declare
                                       I : Dir_Entry;
                                    begin
                                       I.Len := NP'Length;
                                       I.Path (1 .. I.Len) :=
                                         NP (NP'First .. NP'First + I.Len - 1);
                                       Stack.Append (I);
                                    end;
                                 end if;
                              elsif Should_Scan (N) then
                                 Add (Adacovex.Cache.Hash_File (NP));
                              end if;
                           end;
                        end loop;
                     else
                        Start_Search (S, CP, "");
                        while More_Entries (S) loop
                           Get_Next_Entry (S, E);
                           declare
                              N : constant String := Simple_Name (E);
                           begin
                              if Kind (E) = Directory then
                                 if N /= "."
                                   and then N /= ".."
                                   and then N /= ".git"
                                   and then N /= ".jj"
                                   and then N /= ".hg"
                                   and then N /= ".svn"
                                   and then N /= "obj"
                                   and then N /= "tests"
                                   and then N /= "config"
                                   and then N /= ".adacovex"
                                   and then N /= "alire"
                                   and then N /= "gnatprove"
                                   and then N /= "__pycache__"
                                   and then N /= "node_modules"
                                   and then N /= ".venv"
                                   and then N /= ".headroom"
                                   and then N /= ".lccst"
                                   and then N /= "_build"
                                 then
                                    declare
                                       NP : constant String := Full_Name (E);
                                       I  : Dir_Entry;
                                    begin
                                       I.Len := NP'Length;
                                       I.Path (1 .. I.Len) :=
                                         NP (NP'First .. NP'First + I.Len - 1);
                                       Stack.Append (I);
                                    end;
                                 end if;
                              elsif Kind (E) = Ordinary_File then
                                 if Should_Scan (Simple_Name (E)) then
                                    Add
                                      (Adacovex.Cache.Hash_File
                                         (Full_Name (E)));
                                 end if;
                              end if;
                           end;
                        end loop;
                        End_Search (S);
                     end if;
                  end;
               end if;
            end;
         end loop;
         if HLen = 0 then
            return "";
         end if;
         return Adacovex.Cache.Hash_String (H (1 .. HLen));
      end Source_Tree_Hash;

      --  Whether the project root holds a Makefile variant (implies make).
      function Has_Makefile return Boolean is
      begin
         return
           Ada.Directories.Exists (Target_Dir & "/Makefile")
           or else Ada.Directories.Exists (Target_Dir & "/makefile")
           or else Ada.Directories.Exists (Target_Dir & "/GNUmakefile");
      end Has_Makefile;

      --  Whether the referenced-tool set (and its probe results) came from
      --  the on-disk cache.  Used to skip the PATH walk and version probes.
      From_Cache : Boolean := False;

      --  Cache key (and its image) for the miss-store below.  Kept at
      --  procedure level so the store can run after the probe loop.
      Key_Img : String (1 .. 128) := (others => ' ');
      Key_Len : Natural := 0;
   begin
      --  Serve the referenced-tool set from the on-disk cache when the
      --  project's inputs are unchanged.  The key covers every file the
      --  scan reads, so an unchanged project skips the tree walk and the
      --  per-file word scan entirely; an edit invalidates the key and the
      --  next run re-scans.  The key value is kept for the store step that
      --  runs after a scan.
      declare
         K     : constant String := Tools_Key (Target_Dir);
         Blob  : String (1 .. 8192) := (others => ' ');
         BLen  : Natural := 0;
         Found : Boolean := False;
      begin
         if K'Length > 0 then
            if K'Length <= Key_Img'Last then
               Key_Img (1 .. K'Length) := K;
               Key_Len := K'Length;
            end if;
            Adacovex.Cache.Get_Cached (K, Blob, BLen, Found);
            if Found and then BLen > 0 then
               Deserialize_Set (Blob (1 .. BLen));
               From_Cache := True;
            end if;
         end if;

         if not From_Cache then
            Push_Dir (Target_Dir);

            while not Dir_Stack.Is_Empty loop
               declare
                  Current  : Dir_Entry := Dir_Stack.Last_Element;
                  Dir_Path : String renames Current.Path (1 .. Current.Len);
                  Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
                  SCt      : Natural;
                  STrunc   : Boolean;
                  SOK      : Boolean;
               begin
                  Dir_Stack.Delete_Last;

                  --  Shared snapshot first; direct enumeration only on the
                  --  fallback path (over-cap tree or unreadable snapshot).
                  Adacovex.Dir_Cache.Snapshot
                    (Dir_Path, Snap, SCt, STrunc, SOK);
                  if SOK and then not STrunc then
                     for SI in 1 .. SCt loop
                        declare
                           N    : constant String :=
                             Snap (SI).Name (1 .. Snap (SI).Name_Len);
                           Path : constant String := Dir_Path & "/" & N;
                           Is_D : constant Boolean :=
                             Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind);
                        begin
                           if Is_D then
                              if N /= ".git"
                                and N /= ".jj"
                                and N /= ".hg"
                                and N /= ".svn"
                                and N /= "obj"
                                and N /= "tests"
                                and N /= "config"
                                and N /= ".adacovex"
                                and N /= "alire"
                                and N /= "gnatprove"
                                and N /= "__pycache__"
                                and N /= "node_modules"
                                and N /= ".venv"
                                and N /= ".headroom"
                                and N /= ".lccst"
                                and N /= "_build"
                              then
                                 Push_Dir (Path);
                              end if;
                           elsif Should_Scan (N) then
                              Scan_File (Path);
                           end if;
                        end;
                     end loop;
                  else
                     Start_Search (Search, Dir_Path, "");
                     begin
                        while More_Entries (Search) loop
                           Get_Next_Entry (Search, Ent);
                           declare
                              N    : constant String := Simple_Name (Ent);
                              Path : constant String := Full_Name (Ent);
                           begin
                              if Kind (Ent) = Directory then
                                 if N /= "."
                                   and N /= ".."
                                   and N /= ".git"
                                   and N /= ".jj"
                                   and N /= ".hg"
                                   and N /= ".svn"
                                   and N /= "obj"
                                   and N /= "tests"
                                   and N /= "config"
                                   and N /= ".adacovex"
                                   and N /= "alire"
                                   and N /= "gnatprove"
                                   and N /= "__pycache__"
                                   and N /= "node_modules"
                                   and N /= ".venv"
                                   and N /= ".headroom"
                                   and N /= ".lccst"
                                   and N /= "_build"
                                 then
                                    Push_Dir (Path);
                                 end if;
                              elsif Kind (Ent) = Ordinary_File then
                                 if Should_Scan (N) then
                                    Scan_File (Path);
                                 end if;
                              end if;
                           end;
                        end loop;
                     exception
                        when others =>
                           End_Search (Search);
                           raise;
                     end;
                     End_Search (Search);
                  end if;
               end;
            end loop;

         end if;
      end;

      --  A Makefile at the project root implies make even when no recipe
      --  spells out the driver by name.
      if Has_Makefile then
         for T in System_Tools'Range loop
            if System_Tools (T).Len = 4
              and then System_Tools (T).Name (1 .. 4) = "make"
            then
               Note_Tool (System_Tools (T));
               exit;
            end if;
         end loop;
      end if;

      --  Register every referenced tool that is actually installed on PATH.
      --  Register it as a dev-scope dependency of the root.  Probe its
      --  version ("<Tool> <flag>") when possible.  Tools the project does
      --  not reference, or that are not installed, are skipped.
      --  Append_Dependency also deduplicates against manifest, lockfile, and
      --  GPR deps (for example gnatprove declared in alire-dev.toml).  A
      --  manifest-pinned tool never appears twice.
      --
      --  Cache hit: the probe results were restored with the set.  Each
      --  restored probe is re-validated against the identity digest of the
      --  tool's installed binary before its version is trusted: a tool
      --  upgraded since the set was cached re-probes here (and refreshes
      --  both cache layers), while an unchanged toolchain serves entirely
      --  from cache with no subprocess probes.
      if From_Cache then
         for PI in 1 .. Integer (Probes.Length) loop
            declare
               Nm          : constant String :=
                 Probes (PI).Name (1 .. Probes (PI).NLen);
               Live_Digest : constant String := Tool_Fp_Digest (Nm);
            begin
               if Live_Digest'Length > 0
                 and then Probes (PI).FpLen = Live_Digest'Length
                 and then Probes (PI).Fp (1 .. Live_Digest'Length)
                          = Live_Digest
               then
                  Append_Dependency
                    (Graph,
                     Nm,
                     Probes (PI).Ver (1 .. Probes (PI).VLen),
                     "",
                     "System tool referenced by the project (dev dependency)",
                     "pkg:generic/" & Nm,
                     1,
                     False,
                     Types.Scope_System);
               else
                  --  Upgraded/replaced binary (or a stale digest-free
                  --  entry): probe fresh and refresh the stored set.
                  declare
                     Exe : GNAT.OS_Lib.String_Access :=
                       GNAT.OS_Lib.Locate_Exec_On_Path (Nm);
                     Fp  : constant String :=
                       (if Exe /= null
                        then Adacovex.Cache.Tool_Fingerprint (Exe.all)
                        else "");
                     V   : constant String :=
                       (if Fp'Length > 0
                        then Probe_Version (Nm, "--version")
                        else "");
                     procedure Store is
                     begin
                        if Fp'Length > 0 then
                           Adacovex.Cache.Put_Probe (Nm, Fp, V);
                        end if;
                     end Store;
                  begin
                     if Exe /= null then
                        GNAT.OS_Lib.Free (Exe);
                        Store;
                        Add_Probe_Fp (Nm, V, Adacovex.Cache.Hash_String (Fp));
                        Append_Dependency
                          (Graph,
                           Nm,
                           V,
                           "",
                           "System tool referenced by the project (dev dependency)",
                           "pkg:generic/" & Nm,
                           1,
                           False,
                           Types.Scope_System);
                     end if;
                  end;
               end if;
            end;
         end loop;
      else
         for I in 1 .. Integer (Referenced.Length) loop
            declare
               Name : constant String :=
                 Referenced (I).Name (1 .. Referenced (I).Len);
               Exe  : GNAT.OS_Lib.String_Access :=
                 GNAT.OS_Lib.Locate_Exec_On_Path (Name);
            begin
               if Exe /= null then
                  --  Identity of the installed binary (path + size + mtime).
                  --  Both cache layers below key on it, so an upgraded or
                  --  replaced tool re-probes on the next run instead of
                  --  serving a version the old binary reported.
                  declare
                     Fp : constant String :=
                       Adacovex.Cache.Tool_Fingerprint (Exe.all);
                  begin
                     GNAT.OS_Lib.Free (Exe);
                     --  Version probing spawns a subprocess per tool.  Cache
                     --  the result on disk (7-day TTL), validated against
                     --  the binary fingerprint.  Unchanged toolchains then do
                     --  not pay tens of milliseconds per referenced tool on
                     --  every run; an upgrade re-probes exactly once.
                     declare
                        Probe : String (1 .. 512) := (others => ' ');
                        PLen  : Natural := 0;
                        Found : Boolean := False;
                        --  Version text (up to the 4096-char Probe_Version
                        --  reader cap).  It is copied into a fixed buffer.
                        --  The cache-hit and cache-miss paths then share one
                        --  Append_Dependency call.
                        VBuf  : String (1 .. 4096);
                        VLen  : Natural := 0;
                     begin
                        Adacovex.Cache.Get_Probe
                          (Name, Fp, Probe, PLen, Found);
                        if Found then
                           VLen := PLen;
                           VBuf (1 .. VLen) := Probe (1 .. VLen);
                        else
                           declare
                              V : constant String :=
                                Probe_Version (Name, "--version");
                           begin
                              VLen := V'Length;
                              if VLen > VBuf'Last then
                                 VLen := VBuf'Last;
                              end if;
                              VBuf (1 .. VLen) :=
                                V (V'First .. V'First + VLen - 1);
                           end;
                           Adacovex.Cache.Put_Probe
                             (Name, Fp, VBuf (1 .. VLen));
                        end if;
                        Add_Probe_Fp
                          (Name,
                           VBuf (1 .. VLen),
                           Adacovex.Cache.Hash_String (Fp));
                        Append_Dependency
                          (Graph,
                           Name,
                           VBuf (1 .. VLen),
                           "",
                           "System tool referenced by the project (dev dependency)",
                           "pkg:generic/" & Name,
                           1,
                           False,
                           Types.Scope_System);
                     end;
                  end;
               end if;
            end;
         end loop;
      end if;

      --  Store the freshly scanned set (now including probe results) for
      --  the next run.  On a cache hit nothing is stored (the entry is
      --  still current and complete).
      if not From_Cache and then Key_Len > 0 then
         declare
            S  : constant String := Serialize_Set;
            OK : Boolean;
         begin
            if S'Length > 0 then
               Adacovex.Cache.Put_Cached (Key_Img (1 .. Key_Len), S, OK);
            end if;
         end;
      end if;
   end Discover_System_Dev_Deps;

   --  Fingerprint of everything that contributes vendored components to
   --  the graph.  Every file under the classic vendored roots
   --  (<target>/.adacovex/patches, resources, vendor, assets) is included.
   --  Every file under the language-agnostic vendored directories that
   --  Discover_Generic_Vendored discovers is included (deps, third_party,
   --  node_modules, and more, hashed to depth 3).  Adding, removing, or
   --  editing any of those files changes the digest.  The cached graph is
   --  then invalidated correctly.
   --  Returns "" when no vendored input exists.
   --  @param Target_Dir  Project root directory.
   --  @return SHA256 of the vendored inputs, or "" when none exist.
   function Vendored_Hash (Target_Dir : String) return String is
      use Ada.Directories;
      type Dir_Entry is record
         Path  : Types.Path_Field;
         Len   : Natural := 0;
         Level : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;
      T         : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
      Comb      : String (1 .. Types.Max_Path);
      CLen      : Natural := 0;

      procedure Push_Dir
        (S         : in out Dir_Stacks.Vector;
         Dir       : String;
         Level     : Natural;
         Max_Depth : Natural)
      is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path and then Level <= Max_Depth then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Item.Level := Level;
            S.Append (Item);
         end if;
      end Push_Dir;

      procedure Add (S : String) is
      begin
         if S'Length > 0 and then CLen + S'Length <= Comb'Last then
            Comb (CLen + 1 .. CLen + S'Length) := S;
            CLen := CLen + S'Length;
         end if;
      end Add;

      --  Hash every regular file under Root, descending at most Max_Levels
      --  subdirectories.  It uses its own stack.  The outer vendor walk is
      --  then unaffected.
      procedure Hash_Tree (Root : String; Max_Levels : Natural) is
         H_Stack  : Dir_Stacks.Vector;
         H_Search : Search_Type;
         H_Ent    : Directory_Entry_Type;
      begin
         if not Exists (Root) then
            return;
         end if;
         Push_Dir (H_Stack, Root, 0, Max_Levels);
         while not H_Stack.Is_Empty loop
            declare
               Current  : Dir_Entry := H_Stack.Last_Element;
               Dir_Path : String renames Current.Path (1 .. Current.Len);
               Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
               SCt      : Natural;
               STrunc   : Boolean;
               SOK      : Boolean;
            begin
               H_Stack.Delete_Last;
               --  Shared snapshot first; direct enumeration on fallback.
               Adacovex.Dir_Cache.Snapshot (Dir_Path, Snap, SCt, STrunc, SOK);
               if SOK and then not STrunc then
                  for SI in 1 .. SCt loop
                     declare
                        N    : constant String :=
                          Snap (SI).Name (1 .. Snap (SI).Name_Len);
                        Path : constant String := Dir_Path & "/" & N;
                        Is_D : constant Boolean :=
                          Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind);
                     begin
                        if Is_D then
                           if N /= "_build" and then not Skip_Walk_Dir (N) then
                              Push_Dir
                                (H_Stack, Path, Current.Level + 1, Max_Levels);
                           end if;
                        else
                           Add (Adacovex.Cache.Hash_File (Path));
                        end if;
                     end;
                  end loop;
               else
                  Start_Search (H_Search, Dir_Path, "");
                  begin
                     while More_Entries (H_Search) loop
                        Get_Next_Entry (H_Search, H_Ent);
                        declare
                           N    : constant String := Simple_Name (H_Ent);
                           Path : constant String := Full_Name (H_Ent);
                        begin
                           if Kind (H_Ent) = Directory then
                              if N /= "."
                                and then N /= ".."
                                and then N /= "_build"
                                and then not Skip_Walk_Dir (N)
                              then
                                 Push_Dir
                                   (H_Stack,
                                    Path,
                                    Current.Level + 1,
                                    Max_Levels);
                              end if;
                           elsif Kind (H_Ent) = Ordinary_File then
                              Add (Adacovex.Cache.Hash_File (Path));
                           end if;
                        end;
                     end loop;
                  exception
                     when others =>
                        End_Search (H_Search);
                        raise;
                  end;
                  End_Search (H_Search);
               end if;
            end;
         end loop;
      end Hash_Tree;

      --  Whether a file name is a supported-language project manifest that
      --  can own a vendored directory (the file set Collect_Owner_Test_Names
      --  reads, plus the npm lockfiles it scans).  Hashing these files makes
      --  the graph key sound: editing the owning manifest's test-labelled
      --  sections (or its npm lockfiles) invalidates the cached graph so the
      --  scope classification is recomputed.
      --  @param N  File base name.
      --  @return True for package.json, Cargo.toml, Cargo.lock, go.mod,
      --    composer.json, Gemfile, pom.xml, pyproject.toml, Package.swift,
      --    and the npm lockfiles pnpm-lock.yaml, package-lock.json, and
      --    yarn.lock.
      function Is_Owner_Manifest (N : String) return Boolean is
      begin
         return
           N = "package.json"
           or else N = "Cargo.toml"
           or else N = "Cargo.lock"
           or else N = "go.mod"
           or else N = "composer.json"
           or else N = "Gemfile"
           or else N = "pom.xml"
           or else N = "pyproject.toml"
           or else N = "Package.swift"
           or else N = "pnpm-lock.yaml"
           or else N = "package-lock.json"
           or else N = "yarn.lock";
      end Is_Owner_Manifest;
   begin
      --  Classic doc roots (.adacovex/patches, resources, vendor, assets).
      --  Every regular file counts, at any depth (curated and small).
      Hash_Tree (T & "/.adacovex/patches", 99);
      Hash_Tree (T & "/resources", 99);
      Hash_Tree (T & "/vendor", 99);
      Hash_Tree (T & "/assets", 99);

      --  Language-agnostic vendored directories anywhere in the tree (same
      --  discovery walk as Discover_Generic_Vendored, shallow).  Supported-
      --  language project manifests that can own a vendored directory (for
      --  example tests/e2e/package.json owning tests/e2e/node_modules) are
      --  hashed so an edit to their test-labelled sections invalidates the
      --  cached graph.  The manifests inside vendor roots are already
      --  covered by the Hash_Tree calls above.
      Dir_Stack.Clear;
      Push_Dir (Dir_Stack, Target_Dir, 0, 99);
      while not Dir_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Dir_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Dir_Stack.Delete_Last;
            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     N    : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                  begin
                     if Kind (Ent) = Directory then
                        if N /= "."
                          and then N /= ".."
                          and then not Skip_Walk_Dir (N)
                        then
                           if Is_Vendor_Dir_Name (N) then
                              Hash_Tree
                                (Path, (if N = "node_modules" then 1 else 3));
                           else
                              Push_Dir (Dir_Stack, Path, 0, 99);
                           end if;
                        end if;
                     elsif Kind (Ent) = Ordinary_File
                       and then Is_Owner_Manifest (N)
                     then
                        Add (Adacovex.Cache.Hash_File (Path));
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end;
      end loop;

      if CLen = 0 then
         return "";
      end if;
      return Adacovex.Cache.Hash_String (Comb (1 .. CLen));
   end Vendored_Hash;

   --  Combined content hash of everything that shapes the dependency graph.
   --  The publishing manifest, the dev manifest, and the alire.lock are
   --  included.  Every .gpr file collected from the project tree is
   --  included.  The vendored directories (classic roots and language-
   --  agnostic vendor dirs) are included.  The root project's detected
   --  language mix is included.  It is a cheap probe of the source tree's
   --  file-name distribution.  A source-language change then invalidates
   --  the cached graph too.  Returns "" when no input could be hashed.
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
   is
      T    : constant String :=
        (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
      Comb : String (1 .. Types.Max_Path);
      CLen : Natural := 0;

      procedure Add (S : String) is
      begin
         if S'Length > 0 and then CLen + S'Length <= Comb'Last then
            Comb (CLen + 1 .. CLen + S'Length) := S;
            CLen := CLen + S'Length;
         end if;
      end Add;
   begin
      Add (Adacovex.Cache.Hash_File (Manifest_Path));
      Add (Adacovex.Cache.Hash_File (T & "/alire-dev.toml"));
      Add (Adacovex.Cache.Hash_File (T & "/alire/alire.lock"));
      --  A root requirements*.txt shapes the graph (its entries become
      --  pypi components), so editing it must invalidate the cached graph.
      declare
         use Ada.Directories;
         Req_Search : Search_Type;
         Req_Ent    : Directory_Entry_Type;
      begin
         Start_Search (Req_Search, T, "requirements*.txt");
         while More_Entries (Req_Search) loop
            Get_Next_Entry (Req_Search, Req_Ent);
            if Kind (Req_Ent) = Ordinary_File then
               Add (Adacovex.Cache.Hash_File (Full_Name (Req_Ent)));
            end if;
         end loop;
         End_Search (Req_Search);
      exception
         when others =>
            null;
      end;
      Add (Vendored_Hash (Target_Dir));
      declare
         Langs : Lang_Vectors.Vector;
      begin
         Detect_Languages (T, 3, Langs, Skip_Vendored => True);
         Add ("rl:" & Language_Summary (Langs, ""));
      end;
      for I in 1 .. Integer (GPR_Files.Length) loop
         Add
           (Adacovex.Cache.Hash_File
              (GPR_Files (I).Path (1 .. GPR_Files (I).Len)));
      end loop;
      if CLen = 0 then
         return "";
      end if;
      return "graph:" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
   end Graph_Key;

   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean;
      Use_Cache     : Boolean := False)
   is
      Root_Name        : Types.Desc_Field;
      Root_Name_Len    : Natural := 0;
      Root_Version     : Types.Desc_Field;
      Root_Version_Len : Natural := 0;
      Root_License     : Types.Desc_Field;
      Root_License_Len : Natural := 0;
      Root_Desc        : Types.Path_Field;
      Root_Desc_Len    : Natural := 0;
      Root_Website     : Types.Path_Field;
      Root_Website_Len : Natural := 0;
      Proj_File        : Types.Path_Field;
      Proj_File_Len    : Natural := 0;
      Manifest_OK      : Boolean := False;

      GPR_Files    : Path_Vectors.Vector;
      GPR_Name     : Types.Desc_Field;
      GPR_Name_Len : Natural := 0;
      GPR_Deps     : Name_Vectors.Vector;
      Root_GPR_Len : Natural := 0;
      Root_GPR     : Types.Path_Field;
      Root         : Types.Implementation.Component_Info;
   begin
      Graph := Types.Implementation.Component_Vectors.Empty_Vector;

      --  Reset the package-level dependency-scope sets for this resolution.
      Base_Names.Clear;
      Dev_Names.Clear;
      Test_Names.Clear;

      Read_Manifest
        (Manifest_Path,
         Root_Name,
         Root_Name_Len,
         Root_Version,
         Root_Version_Len,
         Root_License,
         Root_License_Len,
         Root_Desc,
         Root_Desc_Len,
         Root_Website,
         Root_Website_Len,
         Proj_File,
         Proj_File_Len,
         Manifest_OK);

      --  Collect the base (publishing manifest), dev (alire-dev.toml), and
      --  test ([[test-depends-on]] in either manifest) dependency crate sets
      --  used to classify every resolved component.
      Read_Manifest_Deps (Manifest_Path, Base_Names, Test_Names);
      declare
         T : constant String :=
           (if Target_Dir'Length > 0
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
      begin
         if T & "/alire-dev.toml" /= Manifest_Path then
            Read_Manifest_Deps (T & "/alire-dev.toml", Dev_Names, Test_Names);
         end if;
      end;

      Collect_GPR_Files (Target_Dir, GPR_Files);

      --  Serve a previously resolved (unchanged) graph straight from the
      --  on-disk result cache instead of re-parsing the lockfile and every
      --  .gpr file.  The directory walk above is cheap.  The recursive GPR
      --  and lock parsing that it saves is not cheap.
      if Use_Cache then
         declare
            K     : constant String :=
              Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
            Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
            Blen  : Natural;
            Found : Boolean;
         begin
            if K'Length > 0 then
               Adacovex.Cache.Get_Cached (K, Blob, Blen, Found);
               if Found
                 and then Graph_Store.Deserialize (Blob (1 .. Blen), Graph)
               then
                  Success := True;
                  return;
               end if;
            end if;
         end;
      end if;

      --  Locate the root .gpr.  Use the manifest project-files entry if
      --  present.  Otherwise use a .gpr whose project name matches the
      --  manifest crate name.
      if Proj_File_Len > 0 then
         declare
            Cand : constant String :=
              Target_Dir & "/" & Proj_File (1 .. Proj_File_Len);
         begin
            if Ada.Directories.Exists (Cand) then
               Root_GPR_Len := Cand'Length;
               for I in Cand'Range loop
                  Root_GPR (I - Cand'First + 1) := Cand (I);
               end loop;
            end if;
         end;
      end if;
      if Root_GPR_Len = 0 then
         if Root_Name_Len > 0 then
            Find_GPR
              (GPR_Files,
               Root_Name (1 .. Root_Name_Len),
               Root_GPR,
               Root_GPR_Len);
         end if;
      end if;

      if Root_GPR_Len > 0 then
         Parse_GPR
           (Root_GPR (1 .. Root_GPR_Len), GPR_Name, GPR_Name_Len, GPR_Deps);
      end if;

      --  Root component (index 1).  Name falls back to the GPR project name.
      if Root_Name_Len = 0 then
         if GPR_Name_Len > 0 then
            Set_Field (Root_Name, Root_Name_Len, GPR_Name (1 .. GPR_Name_Len));
         else
            Set_Field
              (Root_Name,
               Root_Name_Len,
               Ada.Directories.Simple_Name (Target_Dir));
         end if;
      end if;

      declare
         V : constant String :=
           (if Root_Version_Len > 0
            then
              Root_Name (1 .. Root_Name_Len)
              & "@"
              & Root_Version (1 .. Root_Version_Len)
            else Root_Name (1 .. Root_Name_Len));
      begin
         Set_Path (Root.PURL, Root.PURL_Len, "pkg:alire/" & V);
         Set_Path (Root.Ref, Root.Ref_Len, "pkg:alire/" & V);
      end;
      --  Root language.  The top languages of the project's own sources are
      --  used (vendored directories excluded).  The SBOM root component then
      --  records the language mix that created it (top 3 for mixed trees).
      declare
         Root_T     : constant String :=
           (if Target_Dir'Length > 0
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
         Root_Langs : Lang_Vectors.Vector;
      begin
         Detect_Languages (Root_T, 3, Root_Langs, Skip_Vendored => True);
         if not Root_Langs.Is_Empty then
            declare
               RL : constant String := Language_Summary (Root_Langs, "");
            begin
               if RL'Length > 0 then
                  Set_Field (Root.Language, Root.Language_Len, RL);
               end if;
            end;
         end if;
      end;

      Set_Field (Root.Name, Root.Name_Len, Root_Name (1 .. Root_Name_Len));
      Set_Field
        (Root.Version, Root.Version_Len, Root_Version (1 .. Root_Version_Len));
      Set_Field
        (Root.License, Root.License_Len, Root_License (1 .. Root_License_Len));
      Set_Path
        (Root.Description,
         Root.Description_Len,
         Root_Desc (1 .. Root_Desc_Len));
      if Root_Website_Len > 0 then
         Set_Path
           (Root.Website,
            Root.Website_Len,
            Root_Website (1 .. Root_Website_Len));
      end if;
      Root.Kind := Types.Root_Component;
      Root.Parent := 0;
      Graph.Append (Root);

      --  Resolve alire.lock dependencies (solved crates).
      Read_Alire_Lock (Target_Dir & "/alire/alire.lock", Graph);

      --  Resolve GPR with-clause dependencies, including transitives.
      Resolve_GPR_Deps (Graph, GPR_Files, GPR_Deps, 1, 8);

      --  Add vendored packages overlaid by .adacovex/patches/ docstring
      --  patches (for example a third-party copy under demo/deps) as
      --  scope=vendored dependencies of the root.
      Discover_Vendored_Components (Target_Dir, Graph);

      --  Add language-agnostic vendored components.  These are ecosystem
      --  manifests (package.json, Cargo.toml, and more) and Ada library dirs
      --  under any vendor-named directory (third_party, deps, node_modules,
      --  and more).  Each has its ecosystem PURL and detected language or
      --  languages.
      Discover_Generic_Vendored (Target_Dir, Graph);

      --  Register manifest-declared deps (base from alire.toml, dev from
      --  alire-dev.toml) that no GPR with-clause or lockfile resolved.  The
      --  SBOM captures the declared dependency set.  This applies even for
      --  zero-`with` projects whose toolchain deps live only in the dev
      --  manifest.
      Register_Manifest_Deps (Target_Dir, Graph, Base_Names, Dev_Names);

      --  Register the root's Python requirements (requirements*.txt) as
      --  dev-scope pypi dependencies resolved from the package registry.
      Register_Root_Python_Deps (Target_Dir, Graph);

      Success := Root.Name_Len > 0;

      --  Store the freshly resolved graph for the next run.  Store it only on
      --  success.  A partial graph is then never cached.
      if Use_Cache then
         declare
            K  : constant String :=
              Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
            OK : Boolean;
         begin
            if K'Length > 0 then
               declare
                  S_Blob : constant String := Graph_Store.Serialize (Graph);
               begin
                  if S_Blob'Length > 0 then
                     Adacovex.Cache.Put_Cached (K, S_Blob, OK);
                  end if;
               end;
            end if;
         end;
      end if;
   end Build_Dependency_Graph;

end Adacovex.Parsers.Manifest;
