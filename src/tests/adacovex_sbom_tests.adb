with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Parsers.Manifest;
with Adacovex.Cache;
with Adacovex.Renderers.SBOM; use Adacovex.Renderers.SBOM;
with GNAT.OS_Lib;             use GNAT.OS_Lib;

package body Adacovex_SBOM_Tests is

   Fixture : constant String := "obj/sbom_fixture";

   function Contains (S : String; Sub : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (S, Sub) > 0;
   end Contains;

   function Count_Name
     (Graph : Component_Vectors.Vector; Name : String) return Natural
   is
      N : Natural := 0;
   begin
      for I in 1 .. Integer (Graph.Length) loop
         if Graph (I).Name_Len = Name'Length
           and then Graph (I).Name (1 .. Name'Length) = Name
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Name;

   function Has_Digit (S : String) return Boolean is
   begin
      for I in S'Range loop
         if S (I) in '0' .. '9' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Digit;

   function Find_Name
     (Graph : Component_Vectors.Vector; Name : String) return Component_Info
   is
      C : Component_Info;
   begin
      for I in 1 .. Integer (Graph.Length) loop
         if Graph (I).Name_Len = Name'Length
           and then Graph (I).Name (1 .. Name'Length) = Name
         then
            return Graph (I);
         end if;
      end loop;
      return C;
   end Find_Name;

   --  Every line must carry an even number of quote characters so that
   --  strings open and close on the same line.
   function Quotes_Balanced (S : String) return Boolean is
      Count : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) = '"' then
            Count := Count + 1;
         end if;
         if S (I) = ASCII.LF then
            if Count mod 2 /= 0 then
               return False;
            end if;
            Count := 0;
         end if;
      end loop;
      return Count mod 2 = 0;
   end Quotes_Balanced;

   --  Braces and brackets must balance across the document.  The fixtures
   --  used here never put braces inside string values.
   function Braces_Balanced (S : String) return Boolean is
      Depth : Integer := 0;
   begin
      for I in S'Range loop
         case S (I) is
            when '{' | '[' =>
               Depth := Depth + 1;

            when '}' | ']' =>
               Depth := Depth - 1;

            when others    =>
               null;
         end case;
         if Depth < 0 then
            return False;
         end if;
      end loop;
      return Depth = 0;
   end Braces_Balanced;

   function Read_All (Path : String) return String is
      F    : Ada.Text_IO.File_Type;
      Buf  : String (1 .. 200_000);
      Last : Natural := 0;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Line : String (1 .. 8_192);
            L    : Natural;
         begin
            Ada.Text_IO.Get_Line (F, Line, L);
            Buf (Last + 1 .. Last + L) := Line (1 .. L);
            Last := Last + L;
            Last := Last + 1;
            Buf (Last) := ASCII.LF;
         end;
      end loop;
      Ada.Text_IO.Close (F);
      return Buf (1 .. Last);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         return "";
   end Read_All;

   procedure Write_File (Path : String; Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Write_File;

   procedure Make_Fixture is
   begin
      Ada.Directories.Create_Path (Fixture & "/alire");
      Write_File
        (Fixture & "/alire.toml",
         "name = ""fixture"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "licenses = ""MIT"""
         & ASCII.LF
         & "project-files = [""fixture.gpr""]"
         & ASCII.LF);
      Write_File
        (Fixture & "/fixture.gpr",
         "with ""lib_a"";"
         & ASCII.LF
         & "with ""lib_b"";"
         & ASCII.LF
         & "project Fixture is"
         & ASCII.LF
         & "end Fixture;"
         & ASCII.LF);
      Ada.Directories.Create_Path (Fixture & "/lib_a");
      Write_File
        (Fixture & "/lib_a/lib_a.gpr",
         "with ""lib_c"";"
         & ASCII.LF
         & "project Lib_A is"
         & ASCII.LF
         & "end Lib_A;"
         & ASCII.LF);
      Ada.Directories.Create_Path (Fixture & "/lib_b");
      Write_File
        (Fixture & "/lib_b/lib_b.gpr",
         "project Lib_B is" & ASCII.LF & "end Lib_B;" & ASCII.LF);
      Write_File
        (Fixture & "/alire/alire.lock",
         "# Alire lockfile"
         & ASCII.LF
         & "[solution]"
         & ASCII.LF
         & "[solution.context]"
         & ASCII.LF
         & "solved = true"
         & ASCII.LF
         & "[[solution.state]]"
         & ASCII.LF
         & "crate = ""lib_c"""
         & ASCII.LF
         & "fulfilment = ""solved"""
         & ASCII.LF
         & "transitivity = ""direct"""
         & ASCII.LF
         & "versions = ""^2.0.0"""
         & ASCII.LF
         & "[solution.state.release]"
         & ASCII.LF
         & "name = ""lib_c"""
         & ASCII.LF
         & "version = ""2.0.0"""
         & ASCII.LF
         & "licenses = ""Apache-2.0"""
         & ASCII.LF
         & "description = ""Lib C library"""
         & ASCII.LF);
   end Make_Fixture;

   --  Fixture with BOTH the publishing manifest and alire-dev.toml declaring
   --  dependencies, and a root .gpr with no with-clauses and no lockfile: the
   --  dev deps must still be registered as dev-scope components.
   procedure Make_Dep_Fixture is
      D : constant String := "obj/sbom_dep_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""depfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "licenses = ""MIT"""
         & ASCII.LF
         & "project-files = [""depfix.gpr""]"
         & ASCII.LF
         & "[[depends-on]]"
         & ASCII.LF
         & "libbase = ""^1.0"""
         & ASCII.LF);
      Write_File
        (D & "/alire-dev.toml",
         "name = ""depfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "[[depends-on]]"
         & ASCII.LF
         & "libdev1 = ""*"""
         & ASCII.LF
         & "libdev2 = ""^2.0"""
         & ASCII.LF);
      Write_File
        (D & "/depfix.gpr",
         "project Depfix is" & ASCII.LF & "end Depfix;" & ASCII.LF);
   end Make_Dep_Fixture;

   --  Fixture whose dev-facing files (Makefile, shell script, CI workflow)
   --  reference system tools: Discover_System_Dev_Deps must register the
   --  referenced tools that are installed on PATH as dev-scope components,
   --  and never register unreferenced or fictional tools.
   procedure Make_Sysdep_Fixture is
      D : constant String := "obj/sbom_sysdep_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""sysfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "project-files = [""sysfix.gpr""]"
         & ASCII.LF);
      Write_File
        (D & "/sysfix.gpr",
         "project Sysfix is" & ASCII.LF & "end Sysfix;" & ASCII.LF);
      Write_File
        (D & "/Makefile",
         "build:"
         & ASCII.LF
         & ASCII.HT
         & "alr build"
         & ASCII.LF
         & ASCII.HT
         & "python3 tools/gen.py"
         & ASCII.LF
         & ASCII.HT
         & "git status"
         & ASCII.LF
         & ASCII.HT
         & "gnatprove -P sysfix.gpr"
         & ASCII.LF);
      Write_File
        (D & "/build.sh",
         "#!/bin/sh"
         & ASCII.LF
         & "git rev-parse HEAD"
         & ASCII.LF
         & "make -C . all"
         & ASCII.LF);
      Write_File
        (D & "/.github/workflows/ci.yml",
         "jobs:"
         & ASCII.LF
         & "  build:"
         & ASCII.LF
         & "    steps:"
         & ASCII.LF
         & "      - run: python3 -m pytest"
         & ASCII.LF);
   end Make_Sysdep_Fixture;

   --  Fixture with language-agnostic vendored dependencies: an npm
   --  node_modules tree (shallow, one component per package) and a generic
   --  vendor/ library whose source files span several languages (the
   --  directory must become ONE component with a top-3 language summary).
   procedure Make_Vendored_Fixture is
      D : constant String := "obj/sbom_vend_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""vendfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "project-files = [""vendfix.gpr""]"
         & ASCII.LF);
      Write_File
        (D & "/package.json", "{""name"":""vendfix"",""version"":""1.0.0""}");
      Write_File
        (D & "/node_modules/left-pad/package.json",
         "{""name"":""left-pad"",""version"":""1.3.0""}");
      Write_File
        (D & "/node_modules/lodash/package.json",
         "{""name"":""lodash"",""version"":""4.17.21""}");
      Write_File (D & "/vendor/mixlib/a.js", "var a = 1;" & ASCII.LF);
      Write_File (D & "/vendor/mixlib/b.py", "def f(): pass" & ASCII.LF);
      Write_File (D & "/vendor/mixlib/c.go", "package main" & ASCII.LF);
   end Make_Vendored_Fixture;

   --  Fixture declaring a base dependency, a [[test-depends-on]] dependency
   --  in the publishing manifest, and a [[test-depends-on]] dependency in
   --  the dev manifest: the test-labelled crates must be classified
   --  Scope_Test regardless of which manifest declared them.
   procedure Make_Test_Dep_Fixture is
      D : constant String := "obj/sbom_testdep_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tdfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "project-files = [""tdfix.gpr""]"
         & ASCII.LF
         & "[[depends-on]]"
         & ASCII.LF
         & "testbase = ""^1.0"""
         & ASCII.LF
         & "[[test-depends-on]]"
         & ASCII.LF
         & "testrun = ""*"""
         & ASCII.LF);
      Write_File
        (D & "/alire-dev.toml",
         "name = ""tdfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "[[test-depends-on]]"
         & ASCII.LF
         & "devtest = ""^2.0"""
         & ASCII.LF);
      Write_File
        (D & "/tdfix.gpr",
         "project Tdfix is" & ASCII.LF & "end Tdfix;" & ASCII.LF);
   end Make_Test_Dep_Fixture;

   --  Fixture whose test suite lives in a tests/ directory: the root .gpr
   --  with-clauses the test harness project (tests/test_suite.gpr), which
   --  itself with-clauses a library.  The library is referenced only from a
   --  test project file, so it must be classified Scope_Test.
   procedure Make_Test_GPR_Fixture is
      D : constant String := "obj/sbom_testgpr_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tgfix"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "project-files = [""tgfix.gpr""]"
         & ASCII.LF);
      Write_File
        (D & "/tgfix.gpr",
         "with ""test_suite"";"
         & ASCII.LF
         & "project Tgfix is"
         & ASCII.LF
         & "end Tgfix;"
         & ASCII.LF);
      Ada.Directories.Create_Path (D & "/tests");
      Write_File
        (D & "/tests/test_suite.gpr",
         "with ""libt"";"
         & ASCII.LF
         & "project Test_Suite is"
         & ASCII.LF
         & "end Test_Suite;"
         & ASCII.LF);
      Write_File
        (D & "/tests/libt.gpr",
         "project Libt is" & ASCII.LF & "end Libt;" & ASCII.LF);
   end Make_Test_GPR_Fixture;

   --  Fixture for test-labelled vendored npm dependencies: a node_modules
   --  tree owned by a package.json that declares a "testDependencies"
   --  section alongside devDependencies.  @playwright/test (test-named
   --  package) and jsdom (declared under testDependencies) must be
   --  Scope_Test; lodash (devDependencies only) stays vendored.
   procedure Make_Test_Label_Fixture is
      D : constant String := "obj/sbom_testlabel_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlfx""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/package.json",
         "{"
         & ASCII.LF
         & "  ""name"": ""tlfx"","
         & ASCII.LF
         & "  ""devDependencies"": {"
         & ASCII.LF
         & "    ""@playwright/test"": ""^1.52.0"","
         & ASCII.LF
         & "    ""lodash"": ""^4.17.21"""
         & ASCII.LF
         & "  },"
         & ASCII.LF
         & "  ""testDependencies"": {"
         & ASCII.LF
         & "    ""jsdom"": ""^1.0.0"""
         & ASCII.LF
         & "  }"
         & ASCII.LF
         & "}");
      Write_File
        (D & "/node_modules/@playwright/test/package.json",
         "{""name"":""@playwright/test"",""version"":""1.62.1""}");
      Write_File
        (D & "/node_modules/lodash/package.json",
         "{""name"":""lodash"",""version"":""4.17.21""}");
      Write_File
        (D & "/node_modules/jsdom/package.json",
         "{""name"":""jsdom"",""version"":""1.0.0""}");
   end Make_Test_Label_Fixture;

   --  Fixture whose owning manifest is a Cargo.toml with [dependencies]
   --  and [dev-dependencies]: the dev-dependencies crate (Cargo's native
   --  test-only section) must be Scope_Test, the regular dependency stays
   --  vendored.
   procedure Make_Test_Label_Cargo_Fixture is
      D : constant String := "obj/sbom_testlabel_cargo";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlcargo""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""tlcargo"""
         & ASCII.LF
         & "version = ""0.1.0"""
         & ASCII.LF
         & "[dependencies]"
         & ASCII.LF
         & "serde = ""1.0"""
         & ASCII.LF
         & "[dev-dependencies]"
         & ASCII.LF
         & "mockall = ""0.13"""
         & ASCII.LF);
      Write_File
        (D & "/vendor/mockall/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""mockall"""
         & ASCII.LF
         & "version = ""0.13.0"""
         & ASCII.LF);
      Write_File
        (D & "/vendor/serde/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""serde"""
         & ASCII.LF
         & "version = ""1.0.200"""
         & ASCII.LF);
   end Make_Test_Label_Cargo_Fixture;

   --  Fixture whose owning manifest is a Gemfile: gems inside a
   --  `group :test` block must be Scope_Test, gems declared outside any
   --  test group stay vendored.
   procedure Make_Test_Label_Gem_Fixture is
      D : constant String := "obj/sbom_testlabel_gem";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlgem""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/Gemfile",
         "source ""https://rubygems.org"""
         & ASCII.LF
         & "gem ""rails"""
         & ASCII.LF
         & "group :test do"
         & ASCII.LF
         & "  gem ""rspec"""
         & ASCII.LF
         & "  gem ""capybara"""
         & ASCII.LF
         & "end"
         & ASCII.LF);
      Write_File (D & "/vendor/rspec/Gemfile", "gem ""rspec""" & ASCII.LF);
      Write_File (D & "/vendor/rails/Gemfile", "gem ""rails""" & ASCII.LF);
   end Make_Test_Label_Gem_Fixture;

   --  Fixture whose owning manifest is a pom.xml: a <dependency> block
   --  with a <scope>test</scope> must be Scope_Test, a dependency without
   --  a test scope stays vendored.
   procedure Make_Test_Label_Maven_Fixture is
      D : constant String := "obj/sbom_testlabel_maven";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlmaven""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/pom.xml",
         "<project>"
         & ASCII.LF
         & "  <dependencies>"
         & ASCII.LF
         & "    <dependency>"
         & ASCII.LF
         & "      <groupId>org.mockito</groupId>"
         & ASCII.LF
         & "      <artifactId>mockito-core</artifactId>"
         & ASCII.LF
         & "      <scope>test</scope>"
         & ASCII.LF
         & "    </dependency>"
         & ASCII.LF
         & "    <dependency>"
         & ASCII.LF
         & "      <groupId>com.example</groupId>"
         & ASCII.LF
         & "      <artifactId>core-lib</artifactId>"
         & ASCII.LF
         & "    </dependency>"
         & ASCII.LF
         & "  </dependencies>"
         & ASCII.LF
         & "</project>"
         & ASCII.LF);
      Write_File
        (D & "/vendor/mockito-core/pom.xml",
         "<project>"
         & ASCII.LF
         & "  <artifactId>mockito-core</artifactId>"
         & ASCII.LF
         & "</project>"
         & ASCII.LF);
      Write_File
        (D & "/vendor/core-lib/pom.xml",
         "<project>"
         & ASCII.LF
         & "  <artifactId>core-lib</artifactId>"
         & ASCII.LF
         & "</project>"
         & ASCII.LF);
   end Make_Test_Label_Maven_Fixture;

   --  Fixture whose owning manifest is a pyproject.toml: dependencies
   --  declared under a "test" optional-dependencies extra must be
   --  Scope_Test, dependencies under a "dev" extra stay vendored.
   procedure Make_Test_Label_Pypi_Fixture is
      D : constant String := "obj/sbom_testlabel_pypi";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlpypi""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/pyproject.toml",
         "[project.optional-dependencies]"
         & ASCII.LF
         & "test = ["
         & ASCII.LF
         & "  ""pytest"""
         & ASCII.LF
         & "]"
         & ASCII.LF
         & "dev = ["
         & ASCII.LF
         & "  ""black"""
         & ASCII.LF
         & "]"
         & ASCII.LF);
      Write_File
        (D & "/vendor/pytest/pyproject.toml",
         "[project]"
         & ASCII.LF
         & "name = ""pytest"""
         & ASCII.LF
         & "version = ""8.0.0"""
         & ASCII.LF);
      Write_File
        (D & "/vendor/black/pyproject.toml",
         "[project]"
         & ASCII.LF
         & "name = ""black"""
         & ASCII.LF
         & "version = ""24.0.0"""
         & ASCII.LF);
   end Make_Test_Label_Pypi_Fixture;

   --  Fixture whose owning manifest is a composer.json: dependencies
   --  declared under require-dev must be Scope_Test, dependencies under
   --  require stay vendored.
   procedure Make_Test_Label_Composer_Fixture is
      D : constant String := "obj/sbom_testlabel_composer";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlcomposer"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF);
      Write_File
        (D & "/composer.json",
         "{"
         & ASCII.LF
         & "  ""require"": {"
         & ASCII.LF
         & "    ""monolog/monolog"": ""^2.0"""
         & ASCII.LF
         & "  },"
         & ASCII.LF
         & "  ""require-dev"": {"
         & ASCII.LF
         & "    ""phpunit/phpunit"": ""^9.0"""
         & ASCII.LF
         & "  }"
         & ASCII.LF
         & "}");
      Write_File
        (D & "/vendor/phpunit/phpunit/composer.json",
         "{""name"":""phpunit/phpunit"",""version"":""9.6.0""}");
      Write_File
        (D & "/vendor/monolog/monolog/composer.json",
         "{""name"":""monolog/monolog"",""version"":""2.9.0""}");
   end Make_Test_Label_Composer_Fixture;

   --  Fixture whose owning manifest is a Package.swift: dependencies
   --  declared inside a .testTarget(...) block must be Scope_Test, a
   --  dependency of a plain .target stays vendored.
   procedure Make_Test_Label_Swift_Fixture is
      D : constant String := "obj/sbom_testlabel_swift";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlswift""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/Package.swift",
         "// swift-tools-version:5.9"
         & ASCII.LF
         & "import PackageDescription"
         & ASCII.LF
         & "let package = Package("
         & ASCII.LF
         & "  name: ""App"","
         & ASCII.LF
         & "  targets: ["
         & ASCII.LF
         & "    .target("
         & ASCII.LF
         & "      name: ""CoreLib"","
         & ASCII.LF
         & "      dependencies: [""SupportLib""]"
         & ASCII.LF
         & "    ),"
         & ASCII.LF
         & "    .testTarget("
         & ASCII.LF
         & "      name: ""AppTests"","
         & ASCII.LF
         & "      dependencies: [""TestHelpers""]"
         & ASCII.LF
         & "    )"
         & ASCII.LF
         & "  ]"
         & ASCII.LF
         & ")"
         & ASCII.LF);
      Write_File
        (D & "/vendor/TestHelpers/Package.swift",
         "// swift-tools-version:5.9" & ASCII.LF);
      Write_File
        (D & "/vendor/SupportLib/Package.swift",
         "// swift-tools-version:5.9" & ASCII.LF);
   end Make_Test_Label_Swift_Fixture;

   --  Fixture whose owning manifest is a go.mod: Go has no native
   --  test-only section, so the name heuristic is the signal.  A module
   --  path whose last segment starts or ends with "test"
   --  (github.com/stretchr/testify) must be Scope_Test; a regular module
   --  stays vendored.
   procedure Make_Test_Label_Go_Fixture is
      D : constant String := "obj/sbom_testlabel_go";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlgo""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/go.mod",
         "module example.com/app"
         & ASCII.LF
         & ASCII.LF
         & "go 1.21"
         & ASCII.LF
         & ASCII.LF
         & "require ("
         & ASCII.LF
         & "    github.com/stretchr/testify v1.8.4"
         & ASCII.LF
         & "    github.com/foo/bar v0.1.0"
         & ASCII.LF
         & ")"
         & ASCII.LF);
      Write_File
        (D & "/vendor/testify/go.mod",
         "module github.com/stretchr/testify"
         & ASCII.LF
         & "go 1.21"
         & ASCII.LF);
      Write_File
        (D & "/vendor/barlib/go.mod",
         "module github.com/foo/bar" & ASCII.LF & "go 1.21" & ASCII.LF);
   end Make_Test_Label_Go_Fixture;

   --  Fixture whose owning manifest is a Cargo.toml without a
   --  [dev-dependencies] section, plus a Cargo.lock: the name heuristic
   --  applies to lockfile-resolved crate names, so the test-case crate
   --  must be Scope_Test while serde stays vendored.
   procedure Make_Test_Label_Cargo_Lock_Fixture is
      D : constant String := "obj/sbom_testlabel_cargolock";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tlcargolock"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF);
      Write_File
        (D & "/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""tlcargolock"""
         & ASCII.LF
         & "version = ""0.1.0"""
         & ASCII.LF
         & "[dependencies]"
         & ASCII.LF
         & "serde = ""1.0"""
         & ASCII.LF);
      Write_File
        (D & "/Cargo.lock",
         "# This file is automatically @generated by Cargo."
         & ASCII.LF
         & "version = 3"
         & ASCII.LF
         & ASCII.LF
         & "[[package]]"
         & ASCII.LF
         & "name = ""test-case"""
         & ASCII.LF
         & "version = ""0.3.3"""
         & ASCII.LF
         & ASCII.LF
         & "[[package]]"
         & ASCII.LF
         & "name = ""serde"""
         & ASCII.LF
         & "version = ""1.0.200"""
         & ASCII.LF);
      Write_File
        (D & "/vendor/test-case/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""test-case"""
         & ASCII.LF
         & "version = ""0.3.3"""
         & ASCII.LF);
      Write_File
        (D & "/vendor/serde/Cargo.toml",
         "[package]"
         & ASCII.LF
         & "name = ""serde"""
         & ASCII.LF
         & "version = ""1.0.200"""
         & ASCII.LF);
   end Make_Test_Label_Cargo_Lock_Fixture;

   --  Fixture whose owning manifest is a package.json without any
   --  test-labelled section, plus a pnpm-lock.yaml: the name heuristic
   --  applies to lockfile-resolved names, so @playwright/test (which the
   --  lockfile lists) must be Scope_Test while lodash stays vendored.
   procedure Make_Test_Label_Lock_Fixture is
      D : constant String := "obj/sbom_testlabel_lock";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""tllock""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Write_File
        (D & "/package.json",
         "{"
         & ASCII.LF
         & "  ""name"": ""tllock"","
         & ASCII.LF
         & "  ""devDependencies"": {"
         & ASCII.LF
         & "    ""lodash"": ""^4.17.21"""
         & ASCII.LF
         & "  }"
         & ASCII.LF
         & "}");
      Write_File
        (D & "/pnpm-lock.yaml",
         "lockfileVersion: '9.0'"
         & ASCII.LF
         & ASCII.LF
         & "importers:"
         & ASCII.LF
         & ASCII.LF
         & "  .:"
         & ASCII.LF
         & "    devDependencies:"
         & ASCII.LF
         & "      '@playwright/test':"
         & ASCII.LF
         & "        specifier: ^1.52.0"
         & ASCII.LF
         & "        version: 1.62.1"
         & ASCII.LF
         & ASCII.LF
         & "packages:"
         & ASCII.LF
         & ASCII.LF
         & "  '@playwright/test@1.62.1':"
         & ASCII.LF
         & "    resolution: {integrity: sha512-DTcUc8qii+cpHvtOwggMtBRMjKZHXYWdw8syRYu2vtzuq4Wxphqq4NfCs5Zt44L6mA8rfDfj+PHnxFc/FeK6mQ"
         & "==}"
         & ASCII.LF
         & "    hasBin: true"
         & ASCII.LF);
      Write_File
        (D & "/node_modules/@playwright/test/package.json",
         "{""name"":""@playwright/test"",""version"":""1.62.1""}");
      Write_File
        (D & "/node_modules/lodash/package.json",
         "{""name"":""lodash"",""version"":""4.17.21""}");
   end Make_Test_Label_Lock_Fixture;

   --  Fixture whose alire.lock resolves crates the manifest does not
   --  declare: the name heuristic applies to lockfile-resolved crates,
   --  so a crate named test_utils must be Scope_Test while lib_c stays
   --  transitive.
   procedure Make_Test_Lock_Heuristic_Fixture is
      D : constant String := "obj/sbom_lockheur_fixture";
   begin
      Write_File
        (D & "/alire.toml",
         "name = ""lhfix""" & ASCII.LF & "version = ""1.0.0""" & ASCII.LF);
      Ada.Directories.Create_Path (D & "/alire");
      Write_File
        (D & "/alire/alire.lock",
         "# Alire lockfile"
         & ASCII.LF
         & "[solution]"
         & ASCII.LF
         & "[solution.context]"
         & ASCII.LF
         & "solved = true"
         & ASCII.LF
         & "[[solution.state]]"
         & ASCII.LF
         & "crate = ""test_utils"""
         & ASCII.LF
         & "fulfilment = ""solved"""
         & ASCII.LF
         & "transitivity = ""direct"""
         & ASCII.LF
         & "[solution.state.release]"
         & ASCII.LF
         & "name = ""test_utils"""
         & ASCII.LF
         & "version = ""1.0.0"""
         & ASCII.LF
         & "licenses = ""MIT"""
         & ASCII.LF
         & "[[solution.state]]"
         & ASCII.LF
         & "crate = ""lib_c"""
         & ASCII.LF
         & "fulfilment = ""solved"""
         & ASCII.LF
         & "transitivity = ""direct"""
         & ASCII.LF
         & "[solution.state.release]"
         & ASCII.LF
         & "name = ""lib_c"""
         & ASCII.LF
         & "version = ""2.0.0"""
         & ASCII.LF
         & "licenses = ""Apache-2.0"""
         & ASCII.LF);
   end Make_Test_Lock_Heuristic_Fixture;

   procedure Make_Demo_Graph (Graph : out Component_Vectors.Vector) is
      Root : Component_Info;
      Dep  : Component_Info;
   begin
      Graph := Component_Vectors.Empty_Vector;

      Root.Name (1 .. 4) := "demo";
      Root.Name_Len := 4;
      Root.Version (1 .. 5) := "1.0.0";
      Root.Version_Len := 5;
      Root.License (1 .. 3) := "MIT";
      Root.License_Len := 3;
      Root.PURL (1 .. 20) := "pkg:alire/demo@1.0.0";
      Root.PURL_Len := 20;
      Root.Ref (1 .. 20) := "pkg:alire/demo@1.0.0";
      Root.Ref_Len := 20;
      Root.Description (1 .. 17) := "Demo root project";
      Root.Description_Len := 17;
      Root.Kind := Root_Component;
      Root.Parent := 0;
      Graph.Append (Root);

      Dep.Name (1 .. 4) := "libx";
      Dep.Name_Len := 4;
      Dep.Version (1 .. 5) := "2.0.0";
      Dep.Version_Len := 5;
      Dep.License (1 .. 10) := "Apache-2.0";
      Dep.License_Len := 10;
      Dep.PURL (1 .. 20) := "pkg:alire/libx@2.0.0";
      Dep.PURL_Len := 20;
      Dep.Ref (1 .. 20) := "pkg:alire/libx@2.0.0";
      Dep.Ref_Len := 20;
      Dep.Description (1 .. 26) := "Says ""hi"" and ""bye"" quotes";
      Dep.Description_Len := 26;
      Dep.Kind := Dependency_Component;
      Dep.Parent := 1;
      Graph.Append (Dep);
   end Make_Demo_Graph;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  Proof-aware property mapping (honest assessed level, not a coarse
      --  Gold/Platinum collapse).
      R.Check (Proof_Level_Property (Stone) = "Stone", "proof Stone -> Stone");
      R.Check
        (Proof_Level_Property (Bronze) = "Bronze", "proof Bronze -> Bronze");
      R.Check
        (Proof_Level_Property (Silver) = "Silver", "proof Silver -> Silver");
      R.Check (Proof_Level_Property (Gold) = "Gold", "proof Gold -> Gold");
      R.Check
        (Proof_Level_Property (Platinum) = "Platinum",
         "proof Platinum -> Platinum");

      --  DAL target property mapping.
      R.Check (DAL_Property_Value (DAL_A) = "DAL-A", "dal DAL-A");
      R.Check (DAL_Property_Value (DAL_B) = "DAL-B", "dal DAL-B");
      R.Check (DAL_Property_Value (DAL_C) = "DAL-C", "dal DAL-C");
      R.Check (DAL_Property_Value (DAL_D) = "DAL-D", "dal DAL-D");
      R.Check (DAL_Property_Value (DAL_E) = "", "dal DAL-E empty");

      --  Standard-aware level-label property mapping.
      R.Check
        (Level_Property (DO_178C, DAL_C) = "DAL-C", "level DO-178C DAL-C");
      R.Check
        (Level_Property (ISO_26262, DAL_C) = "ASIL B",
         "level ISO 26262 ASIL B");
      R.Check
        (Level_Property (ISO_26262, DAL_A) = "ASIL D",
         "level ISO 26262 ASIL D");
      R.Check
        (Level_Property (IEC_62304, DAL_C) = "Class A",
         "level IEC 62304 Class A");
      R.Check (Level_Property (ISO_26262, DAL_E) = "", "level DAL-E empty");

      --  All-standards joined property values (--standard=all).
      R.Check
        (All_Standards_Property = "DO-178C, ISO 26262, IEC 62304",
         "all standards joined names");
      R.Check
        (All_Levels_Property (DAL_C) = "DAL-C / ASIL B / Class A",
         "all levels DAL-C joined");
      R.Check
        (All_Levels_Property (DAL_A) = "DAL-A / ASIL D / Class C",
         "all levels DAL-A joined");
      R.Check
        (All_Levels_Property (DAL_E) = "DAL-E / QM / No class",
         "all levels DAL-E joined");

      --  Dependency-graph resolution from an Alire fixture project.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         Root    : Component_Info;
         C       : Component_Info;
      begin
         Make_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           (Fixture, Fixture & "/alire.toml", Graph, Success);

         R.Check (Success, "manifest graph success");
         R.Check
           (Integer (Graph.Length) = 4, "manifest graph has 4 components");

         Root := Graph (1);
         R.Check (Root.Kind = Root_Component, "graph(1) is the root");
         R.Check
           (Root.Name_Len = 7 and Root.Name (1 .. 7) = "fixture",
            "root name = fixture");
         R.Check
           (Root.Version_Len = 5 and Root.Version (1 .. 5) = "1.0.0",
            "root version = 1.0.0");
         R.Check
           (Root.License_Len = 3 and Root.License (1 .. 3) = "MIT",
            "root license = MIT");
         R.Check
           (Root.PURL_Len = 23
            and Root.PURL (1 .. 23) = "pkg:alire/fixture@1.0.0",
            "root purl");

         R.Check (Count_Name (Graph, "lib_c") = 1, "lib_c deduplicated");
         R.Check (Count_Name (Graph, "lib_a") = 1, "lib_a present once");
         R.Check (Count_Name (Graph, "lib_b") = 1, "lib_b present once");

         C := Find_Name (Graph, "lib_c");
         R.Check (C.Parent = 1, "lib_c parent is root");
         R.Check (not C.From_GPR, "lib_c resolved from alire.lock");
         R.Check
           (C.Version_Len = 5 and C.Version (1 .. 5) = "2.0.0",
            "lib_c version from lock");
         R.Check
           (C.License_Len = 10 and C.License (1 .. 10) = "Apache-2.0",
            "lib_c license from lock");
         R.Check
           (C.PURL_Len = 21 and C.PURL (1 .. 21) = "pkg:alire/lib_c@2.0.0",
            "lib_c purl");

         C := Find_Name (Graph, "lib_a");
         R.Check (C.Parent = 1, "lib_a parent is root");
         R.Check (C.From_GPR, "lib_a resolved from GPR with clause");

         C := Find_Name (Graph, "lib_b");
         R.Check (C.Parent = 1, "lib_b parent is root");
         R.Check (C.From_GPR, "lib_b resolved from GPR with clause");
      end;

      --  Manifest-declared deps register even with no GPR with-clauses:
      --  base from alire.toml, dev from alire-dev.toml.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Dep_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_dep_fixture",
            "obj/sbom_dep_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "dep manifest graph success");
         R.Check
           (Count_Name (Graph, "libbase") = 1, "libbase registered (base)");
         R.Check
           (Count_Name (Graph, "libdev1") = 1, "libdev1 registered (dev)");
         R.Check
           (Count_Name (Graph, "libdev2") = 1, "libdev2 registered (dev)");
         C := Find_Name (Graph, "libbase");
         R.Check (C.Scope = Scope_Base, "libbase scope = base");
         C := Find_Name (Graph, "libdev1");
         R.Check (C.Scope = Scope_Dev, "libdev1 scope = dev");
         C := Find_Name (Graph, "libdev2");
         R.Check (C.Scope = Scope_Dev, "libdev2 scope = dev");
      end;

      --  System-tool dev dependencies: tools referenced by the project's
      --  dev-facing files and installed on PATH are registered as
      --  system-scope components of the root; unreferenced or fictional
      --  tools are never registered.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
         Exe     : GNAT.OS_Lib.String_Access;

         procedure Expect_If_Installed (Tool : String) is
         begin
            Exe := GNAT.OS_Lib.Locate_Exec_On_Path (Tool);
            if Exe /= null then
               GNAT.OS_Lib.Free (Exe);
               R.Check
                 (Count_Name (Graph, Tool) = 1,
                  Tool & " registered (on PATH)");
               C := Find_Name (Graph, Tool);
               R.Check (C.Scope = Scope_System, Tool & " scope = system");
               R.Check (C.Parent = 1, Tool & " parent = root");
               R.Check
                 (C.PURL_Len = 12 + Tool'Length
                  and then C.PURL (1 .. 12 + Tool'Length)
                           = "pkg:generic/" & Tool,
                  Tool & " purl");
               --  Version probing: the version is either empty (probe
               --  failed) or a digit-bearing token extracted from the
               --  tool's --version output.
               R.Check
                 (C.Version_Len = 0
                  or else Has_Digit (C.Version (1 .. C.Version_Len)),
                  Tool & " version empty or digit-bearing");
            else
               R.Check
                 (Count_Name (Graph, Tool) = 0,
                  Tool & " not registered (absent from PATH)");
            end if;
         end Expect_If_Installed;
      begin
         Make_Sysdep_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_sysdep_fixture",
            "obj/sbom_sysdep_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "sysdep manifest graph success");
         Adacovex.Parsers.Manifest.Discover_System_Dev_Deps
           ("obj/sbom_sysdep_fixture", Graph);

         --  Fictional tool: never registered whatever PATH holds.
         R.Check
           (Count_Name (Graph, "nonexistent_adacovex_probe") = 0,
            "fictional tool not registered");

         --  Referenced by the fixture (Makefile / build.sh / ci.yml):
         --  registered iff actually installed on PATH.
         Expect_If_Installed ("git");
         Expect_If_Installed ("make");
         Expect_If_Installed ("python3");
         Expect_If_Installed ("alr");
         Expect_If_Installed ("gnatprove");

         --  Installed or not, never referenced by the fixture: never
         --  registered.
         R.Check
           (Count_Name (Graph, "pandoc") = 0,
            "unreferenced tool not registered");
      end;

      --  Cached dependency-graph round-trip: resolving the same fixture
      --  twice with Use_Cache serves the second graph from the on-disk
      --  result cache (keyed by manifest + lockfile + .gpr contents) instead
      --  of re-parsing the lock and every project file.
      declare
         Pid      : constant String :=
           Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
         CDir     : constant String :=
           "obj/sbom_graph_cache-" & Pid (2 .. Pid'Last);
         Graph1   : Component_Vectors.Vector;
         Graph2   : Component_Vectors.Vector;
         Success  : Boolean := False;
         Prev_Dir : String (1 .. 256) := (others => ' ');
         Prev_Len : Natural := 0;
      begin
         --  Point the result cache at a throwaway dir and restore afterwards,
         --  so the test never touches the real ~/.adacovex cache.
         Adacovex.Cache.Cache_Dir (Prev_Dir, Prev_Len);
         Adacovex.Cache.Set_Cache_Dir (CDir);

         Make_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           (Fixture,
            Fixture & "/alire.toml",
            Graph1,
            Success,
            Use_Cache => True);
         R.Check (Success, "cached graph build succeeds (cache miss)");
         R.Check
           (Integer (Graph1.Length) = 4, "cached graph resolves 4 components");

         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           (Fixture,
            Fixture & "/alire.toml",
            Graph2,
            Success,
            Use_Cache => True);
         R.Check (Success, "cached graph build succeeds (cache hit)");
         R.Check
           (Integer (Graph2.Length) = 4, "cache hit returns the full graph");
         R.Check
           (Count_Name (Graph2, "lib_c") = 1
            and Count_Name (Graph2, "lib_a") = 1
            and Count_Name (Graph2, "lib_b") = 1,
            "cache hit returns the complete component set");

         if Prev_Len > 0 then
            Adacovex.Cache.Set_Cache_Dir (Prev_Dir (1 .. Prev_Len));
         end if;
         begin
            if Ada.Directories.Exists (CDir) then
               Ada.Directories.Delete_Tree (CDir);
            end if;
         exception
            when others =>
               null;
         end;
      end;

      --  Tools-set cache round-trip: the first Discover_System_Dev_Deps
      --  scans the fixture and stores the referenced-tool set; the second
      --  call (same cache dir, unchanged fixture) serves the set from the
      --  on-disk cache instead of re-scanning, and both calls register the
      --  same dev-scope tool components.
      declare
         Pid      : constant String :=
           Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
         CDir     : constant String :=
           "obj/sbom_tools_cache-" & Pid (2 .. Pid'Last);
         G1       : Component_Vectors.Vector;
         G2       : Component_Vectors.Vector;
         Success  : Boolean := False;
         Prev_Dir : String (1 .. 256) := (others => ' ');
         Prev_Len : Natural := 0;
      begin
         Adacovex.Cache.Cache_Dir (Prev_Dir, Prev_Len);
         Adacovex.Cache.Set_Cache_Dir (CDir);

         Make_Sysdep_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_sysdep_fixture",
            "obj/sbom_sysdep_fixture/alire.toml",
            G1,
            Success);
         R.Check (Success, "tools-cache graph build succeeds (miss)");
         Adacovex.Parsers.Manifest.Discover_System_Dev_Deps
           ("obj/sbom_sysdep_fixture", G1);

         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_sysdep_fixture",
            "obj/sbom_sysdep_fixture/alire.toml",
            G2,
            Success);
         R.Check (Success, "tools-cache graph build succeeds (hit)");
         Adacovex.Parsers.Manifest.Discover_System_Dev_Deps
           ("obj/sbom_sysdep_fixture", G2);

         --  The second call must register exactly the same tool set as the
         --  first (the cache served the stored set).  git and make are
         --  referenced by the fixture; whether they are installed on PATH
         --  or not, the cached hit must agree with the scanned miss.
         R.Check
           (Count_Name (G2, "git") = Count_Name (G1, "git"),
            "tools-cache hit agrees on git");
         R.Check
           (Count_Name (G2, "make") = Count_Name (G1, "make"),
            "tools-cache hit agrees on make");
         R.Check
           (Count_Name (G2, "alr") = Count_Name (G1, "alr"),
            "tools-cache hit agrees on alr");

         if Prev_Len > 0 then
            Adacovex.Cache.Set_Cache_Dir (Prev_Dir (1 .. Prev_Len));
         end if;
         begin
            if Ada.Directories.Exists (CDir) then
               Ada.Directories.Delete_Tree (CDir);
            end if;
         exception
            when others =>
               null;
         end;
      end;

      --  CycloneDX 1.5 JSON rendering.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/cdx.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (CycloneDX_JSON,
            S,
            Graph,
            "Platinum",
            DO_178C,
            DAL_A,
            False,
            Success);
         R.Check (Success, "cyclonedx written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check (Contains (T, "CycloneDX"), "cdx bomFormat");
            R.Check (Contains (T, "1.5"), "cdx specVersion 1.5");
            R.Check (Contains (T, "pkg:alire/demo@1.0.0"), "cdx root purl");
            R.Check (Contains (T, "pkg:alire/libx@2.0.0"), "cdx dep purl");
            R.Check
              (Contains (T, "adacovex:proof_level"), "cdx proof property");
            R.Check (Contains (T, "Platinum"), "cdx proof value");
            R.Check
              (Contains (T, "adacovex:standard"), "cdx standard property");
            R.Check (Contains (T, "DO-178C"), "cdx standard value");
            R.Check (Contains (T, "adacovex:dal_target"), "cdx dal property");
            R.Check (Contains (T, "DAL-A"), "cdx dal value");
            R.Check (Contains (T, "adacovex:level"), "cdx level property");
            R.Check (Contains (T, "dependencies"), "cdx dependencies section");
            R.Check (Quotes_Balanced (T), "cdx quotes balanced");
            R.Check (Braces_Balanced (T), "cdx braces balanced");
         end;
      end;

      --  SPDX 2.3 JSON rendering.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/spdx.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (SPDX_JSON, S, Graph, "Platinum", DO_178C, DAL_C, False, Success);
         R.Check (Success, "spdx written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check (Contains (T, "SPDX-2.3"), "spdx version");
            R.Check (Contains (T, "SPDXRef-DOCUMENT"), "spdx document ref");
            R.Check (Contains (T, "pkg:alire/demo@1.0.0"), "spdx root purl");
            R.Check (Contains (T, "DEPENDS_ON"), "spdx relationship");
            R.Check (Contains (T, "attributionTexts"), "spdx attribution");
            R.Check
              (Contains (T, "adacovex:proof_level=Platinum"),
               "spdx proof attr");
            R.Check
              (Contains (T, "adacovex:standard=DO-178C"),
               "spdx standard attr");
            R.Check
              (Contains (T, "adacovex:dal_target=DAL-C"), "spdx dal attr");
            R.Check (Contains (T, "adacovex:level=DAL-C"), "spdx level attr");
            R.Check (Quotes_Balanced (T), "spdx quotes balanced");
            R.Check (Braces_Balanced (T), "spdx braces balanced");
         end;
      end;

      --  ISO 26262 assessment emits the standard name and the ASIL label.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/cdx-asil.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (CycloneDX_JSON,
            S,
            Graph,
            "Platinum",
            ISO_26262,
            DAL_C,
            False,
            Success);
         R.Check (Success, "cdx-asil written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check (Contains (T, "ISO 26262"), "cdx-asil standard value");
            R.Check (Contains (T, "ASIL B"), "cdx-asil level value");
            R.Check (Quotes_Balanced (T), "cdx-asil quotes balanced");
         end;
      end;

      --  IEC 62304 assessment emits the standard name and the safety class.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/cdx-iec.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (CycloneDX_JSON,
            S,
            Graph,
            "Gold",
            IEC_62304,
            DAL_C,
            False,
            Success);
         R.Check (Success, "cdx-iec written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check (Contains (T, "IEC 62304"), "cdx-iec standard value");
            R.Check (Contains (T, "Class A"), "cdx-iec level value");
            R.Check (Quotes_Balanced (T), "cdx-iec quotes balanced");
         end;
      end;

      --  --standard=all emits the joined standard names and level labels for
      --  every standard in a single SBOM document.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/cdx-all.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (CycloneDX_JSON,
            S,
            Graph,
            "Platinum",
            DO_178C,
            DAL_C,
            True,
            Success);
         R.Check (Success, "cdx-all written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check
              (Contains (T, "DO-178C, ISO 26262, IEC 62304"),
               "cdx-all standards joined");
            R.Check
              (Contains (T, "DAL-C / ASIL B / Class A"),
               "cdx-all levels joined");
            R.Check
              (Contains (T, "adacovex:dal_target"), "cdx-all dal property");
            R.Check (Contains (T, "DAL-C"), "cdx-all dal value");
            R.Check (Quotes_Balanced (T), "cdx-all quotes balanced");
            R.Check (Braces_Balanced (T), "cdx-all braces balanced");
         end;
      end;

      --  A dependency description containing quote characters must not break
      --  the JSON (validated by the quote-balance check above).
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/escaped.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (CycloneDX_JSON, S, Graph, "Gold", DO_178C, DAL_B, False, Success);
         R.Check (Success, "escaped-json written");
         R.Check
           (Quotes_Balanced (Read_All (S)), "escaped-json quotes balanced");
      end;

      --  Language-agnostic vendored discovery: npm packages under
      --  node_modules (shallow, pkg:npm PURLs, versioned) and a generic
      --  vendor/ library without a manifest (one component, top-3 language
      --  summary from source extensions).  Loose files under vendor/ must
      --  never become components.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Vendored_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_vend_fixture",
            "obj/sbom_vend_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "vendored fixture graph success");
         R.Check (Count_Name (Graph, "left-pad") = 1, "left-pad registered");
         R.Check (Count_Name (Graph, "lodash") = 1, "lodash registered");
         R.Check (Count_Name (Graph, "mixlib") = 1, "mixlib registered");
         R.Check
           (Count_Name (Graph, "a") = 0,
            "loose vendor files never become components");
         R.Check
           (Count_Name (Graph, "vendor") = 0,
            "vendor root itself is not a component");

         C := Find_Name (Graph, "left-pad");
         R.Check (C.Scope = Scope_Vendored, "left-pad scope = vendored");
         R.Check
           (C.PURL_Len = 22 and C.PURL (1 .. 22) = "pkg:npm/left-pad@1.3.0",
            "left-pad npm purl with version");
         R.Check
           (C.Language_Len = 10 and C.Language (1 .. 10) = "JavaScript",
            "left-pad language from extension");

         C := Find_Name (Graph, "mixlib");
         R.Check (C.Scope = Scope_Vendored, "mixlib scope = vendored");
         R.Check
           (C.PURL_Len = 18 and C.PURL (1 .. 18) = "pkg:generic/mixlib",
            "mixlib purl");
         R.Check
           (Ada.Strings.Fixed.Index (C.Language (1 .. C.Language_Len), "Go")
            > 0,
            "mixlib summary lists Go");
         R.Check
           (Ada.Strings.Fixed.Index
              (C.Language (1 .. C.Language_Len), "Python")
            > 0,
            "mixlib summary lists Python");
         R.Check
           (Ada.Strings.Fixed.Index
              (C.Language (1 .. C.Language_Len), "JavaScript")
            > 0,
            "mixlib summary lists JavaScript");
      end;

      --  Test-labelled vendored npm dependencies: a package whose name
      --  carries the test label (@playwright/test) and a package declared
      --  under a "testDependencies" section (jsdom) are Scope_Test; a
      --  devDependencies-only package (lodash) stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_fixture",
            "obj/sbom_testlabel_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label fixture graph success");
         R.Check
           (Count_Name (Graph, "@playwright/test") = 1,
            "@playwright/test registered");
         R.Check (Count_Name (Graph, "jsdom") = 1, "jsdom registered");
         R.Check (Count_Name (Graph, "lodash") = 1, "lodash registered");
         C := Find_Name (Graph, "@playwright/test");
         R.Check
           (C.Scope = Scope_Test,
            "@playwright/test scope = test (test-named package)");
         C := Find_Name (Graph, "jsdom");
         R.Check
           (C.Scope = Scope_Test,
            "jsdom scope = test (testDependencies section)");
         C := Find_Name (Graph, "lodash");
         R.Check
           (C.Scope = Scope_Vendored,
            "lodash scope = vendored (devDependencies only)");
      end;

      --  Cargo [dev-dependencies] is Cargo's native test-only section:
      --  the mockall crate is Scope_Test, the [dependencies] serde stays
      --  vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Cargo_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_cargo",
            "obj/sbom_testlabel_cargo/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label cargo graph success");
         R.Check (Count_Name (Graph, "mockall") = 1, "mockall registered");
         R.Check (Count_Name (Graph, "serde") = 1, "serde registered");
         C := Find_Name (Graph, "mockall");
         R.Check
           (C.Scope = Scope_Test,
            "mockall scope = test (Cargo dev-dependencies)");
         C := Find_Name (Graph, "serde");
         R.Check
           (C.Scope = Scope_Vendored,
            "serde scope = vendored (Cargo dependencies)");
      end;

      --  Gemfile group :test: rspec is Scope_Test, the ungrouped rails gem
      --  stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Gem_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_gem",
            "obj/sbom_testlabel_gem/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label gem graph success");
         R.Check (Count_Name (Graph, "rspec") = 1, "rspec registered");
         R.Check (Count_Name (Graph, "rails") = 1, "rails registered");
         C := Find_Name (Graph, "rspec");
         R.Check
           (C.Scope = Scope_Test, "rspec scope = test (Gemfile :test group)");
         C := Find_Name (Graph, "rails");
         R.Check
           (C.Scope = Scope_Vendored,
            "rails scope = vendored (no test group)");
      end;

      --  pom.xml <scope>test</scope>: mockito-core is Scope_Test, the
      --  unscoped core-lib stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Maven_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_maven",
            "obj/sbom_testlabel_maven/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label maven graph success");
         R.Check
           (Count_Name (Graph, "mockito-core") = 1, "mockito-core registered");
         R.Check (Count_Name (Graph, "core-lib") = 1, "core-lib registered");
         C := Find_Name (Graph, "mockito-core");
         R.Check
           (C.Scope = Scope_Test,
            "mockito-core scope = test (Maven test scope)");
         C := Find_Name (Graph, "core-lib");
         R.Check
           (C.Scope = Scope_Vendored,
            "core-lib scope = vendored (no test scope)");
      end;

      --  pyproject.toml "test" extra: pytest is Scope_Test, the "dev"
      --  extra black stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Pypi_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_pypi",
            "obj/sbom_testlabel_pypi/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label pypi graph success");
         R.Check (Count_Name (Graph, "pytest") = 1, "pytest registered");
         R.Check (Count_Name (Graph, "black") = 1, "black registered");
         C := Find_Name (Graph, "pytest");
         R.Check
           (C.Scope = Scope_Test,
            "pytest scope = test (pyproject test extra)");
         C := Find_Name (Graph, "black");
         R.Check
           (C.Scope = Scope_Vendored, "black scope = vendored (dev extra)");
      end;

      --  composer.json require-dev: phpunit/phpunit is Scope_Test, the
      --  require monolog/monolog stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Composer_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_composer",
            "obj/sbom_testlabel_composer/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label composer graph success");
         R.Check
           (Count_Name (Graph, "phpunit/phpunit") = 1,
            "phpunit/phpunit registered");
         R.Check
           (Count_Name (Graph, "monolog/monolog") = 1,
            "monolog/monolog registered");
         C := Find_Name (Graph, "phpunit/phpunit");
         R.Check
           (C.Scope = Scope_Test,
            "phpunit/phpunit scope = test (composer require-dev)");
         C := Find_Name (Graph, "monolog/monolog");
         R.Check
           (C.Scope = Scope_Vendored,
            "monolog/monolog scope = vendored (composer require)");
      end;

      --  Package.swift .testTarget: the test-target dependency TestHelpers
      --  is Scope_Test, the plain .target dependency SupportLib stays
      --  vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Swift_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_swift",
            "obj/sbom_testlabel_swift/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label swift graph success");
         R.Check
           (Count_Name (Graph, "TestHelpers") = 1, "TestHelpers registered");
         R.Check
           (Count_Name (Graph, "SupportLib") = 1, "SupportLib registered");
         C := Find_Name (Graph, "TestHelpers");
         R.Check
           (C.Scope = Scope_Test,
            "TestHelpers scope = test (Package.swift testTarget)");
         C := Find_Name (Graph, "SupportLib");
         R.Check
           (C.Scope = Scope_Vendored,
            "SupportLib scope = vendored (plain target dependency)");
      end;

      --  go.mod has no native test-only section: the name heuristic is the
      --  signal, so the testify module (last path segment starts with
      --  "test") is Scope_Test and a regular module stays vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Go_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_go",
            "obj/sbom_testlabel_go/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label go graph success");
         R.Check
           (Count_Name (Graph, "github.com/stretchr/testify") = 1,
            "testify module registered");
         R.Check
           (Count_Name (Graph, "github.com/foo/bar") = 1,
            "foo/bar module registered");
         C := Find_Name (Graph, "github.com/stretchr/testify");
         R.Check
           (C.Scope = Scope_Test,
            "testify scope = test (test-named module path)");
         C := Find_Name (Graph, "github.com/foo/bar");
         R.Check
           (C.Scope = Scope_Vendored,
            "foo/bar scope = vendored (regular module)");
      end;

      --  Cargo.lock: the name heuristic applies to lockfile-resolved crate
      --  names, so test-case is Scope_Test even though the owning
      --  Cargo.toml has no [dev-dependencies] section; serde stays
      --  vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Cargo_Lock_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_cargolock",
            "obj/sbom_testlabel_cargolock/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label cargo-lock graph success");
         R.Check (Count_Name (Graph, "test-case") = 1, "test-case registered");
         R.Check (Count_Name (Graph, "serde") = 1, "serde registered");
         C := Find_Name (Graph, "test-case");
         R.Check
           (C.Scope = Scope_Test,
            "test-case scope = test (test-named Cargo.lock crate)");
         C := Find_Name (Graph, "serde");
         R.Check
           (C.Scope = Scope_Vendored,
            "serde scope = vendored (Cargo.lock only)");
      end;

      --  pnpm-lock.yaml: the name heuristic applies to lockfile-resolved
      --  names, so @playwright/test (listed only in the lockfile, not in
      --  a test-labelled package.json section) is Scope_Test; lodash stays
      --  vendored.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Label_Lock_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testlabel_lock",
            "obj/sbom_testlabel_lock/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-label lock graph success");
         R.Check
           (Count_Name (Graph, "@playwright/test") = 1,
            "@playwright/test registered (lockfile)");
         R.Check (Count_Name (Graph, "lodash") = 1, "lodash registered");
         C := Find_Name (Graph, "@playwright/test");
         R.Check
           (C.Scope = Scope_Test,
            "@playwright/test scope = test (test-named lockfile entry)");
         C := Find_Name (Graph, "lodash");
         R.Check
           (C.Scope = Scope_Vendored,
            "lodash scope = vendored (lockfile, not test-named)");
      end;

      --  alire.lock: the name heuristic applies to lockfile-resolved
      --  crates the manifest does not declare, so test_utils is
      --  Scope_Test and lib_c stays transitive.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Lock_Heuristic_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_lockheur_fixture",
            "obj/sbom_lockheur_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "lock heuristic graph success");
         R.Check
           (Count_Name (Graph, "test_utils") = 1, "test_utils registered");
         R.Check (Count_Name (Graph, "lib_c") = 1, "lib_c registered");
         C := Find_Name (Graph, "test_utils");
         R.Check
           (C.Scope = Scope_Test,
            "test_utils scope = test (test-named alire.lock crate)");
         C := Find_Name (Graph, "lib_c");
         R.Check
           (C.Scope = Scope_Transitive,
            "lib_c scope = transitive (alire.lock, not test-named)");
      end;

      --  Markdown SBOM rendering.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/compliance.md";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM
           (Markdown, S, Graph, "Platinum", DO_178C, DAL_C, False, Success);
         R.Check (Success, "markdown written");
         declare
            T : constant String := Read_All (S);
         begin
            R.Check (Contains (T, "DO-178C"), "md standard header");
            R.Check (Contains (T, "DAL-C"), "md level value");
            R.Check (Contains (T, "Platinum"), "md proof level");
            R.Check (Contains (T, "| Component |"), "md table header");
         end;
      end;

      --  Extension_Language: direct unit tests for supported language/format
      --  detection across the full extension table.
      declare
         function EL (Name : String) return String is
         begin
            return Adacovex.Parsers.Manifest.Extension_Language (Name);
         end EL;
      begin
         R.Check (EL ("main.ads") = "Ada", "ads -> Ada");
         R.Check (EL ("main.adb") = "Ada", "adb -> Ada");
         R.Check (EL ("main.ada") = "Ada", "ada -> Ada");
         R.Check (EL ("demo.gpr") = "Ada", "gpr -> Ada");
         R.Check (EL ("app.js") = "JavaScript", "js -> JavaScript");
         R.Check (EL ("app.mjs") = "JavaScript", "mjs -> JavaScript");
         R.Check (EL ("app.cjs") = "JavaScript", "cjs -> JavaScript");
         R.Check (EL ("app.ts") = "TypeScript", "ts -> TypeScript");
         R.Check (EL ("app.tsx") = "TypeScript", "tsx -> TypeScript");
         R.Check (EL ("style.css") = "CSS", "css -> CSS");
         R.Check (EL ("page.html") = "HTML", "html -> HTML");
         R.Check (EL ("page.htm") = "HTML", "htm -> HTML");
         R.Check (EL ("script.py") = "Python", "py -> Python");
         R.Check (EL ("main.go") = "Go", "go -> Go");
         R.Check (EL ("main.rs") = "Rust", "rs -> Rust");
         R.Check (EL ("main.c") = "C", "c -> C");
         R.Check (EL ("main.h") = "C", "h -> C");
         R.Check (EL ("main.cpp") = "C++", "cpp -> C++");
         R.Check (EL ("main.cc") = "C++", "cc -> C++");
         R.Check (EL ("main.cxx") = "C++", "cxx -> C++");
         R.Check (EL ("main.hpp") = "C++", "hpp -> C++");
         R.Check (EL ("main.hh") = "C++", "hh -> C++");
         R.Check (EL ("main.hxx") = "C++", "hxx -> C++");
         R.Check (EL ("main.cs") = "C#", "cs -> C#");
         R.Check (EL ("Main.java") = "Java", "java -> Java");
         R.Check (EL ("app.rb") = "Ruby", "rb -> Ruby");
         R.Check (EL ("app.php") = "PHP", "php -> PHP");
         R.Check (EL ("main.swift") = "Swift", "swift -> Swift");
         R.Check (EL ("main.kt") = "Kotlin", "kt -> Kotlin");
         R.Check (EL ("main.kts") = "Kotlin", "kts -> Kotlin");
         R.Check (EL ("main.scala") = "Scala", "scala -> Scala");
         R.Check (EL ("main.ml") = "OCaml", "ml -> OCaml");
         R.Check (EL ("main.mli") = "OCaml", "mli -> OCaml");
         R.Check (EL ("script.lua") = "Lua", "lua -> Lua");
         R.Check (EL ("script.pl") = "Perl", "pl -> Perl");
         R.Check (EL ("main.hs") = "Haskell", "hs -> Haskell");
         R.Check (EL ("main.ex") = "Elixir", "ex -> Elixir");
         R.Check (EL ("main.exs") = "Elixir", "exs -> Elixir");
         R.Check (EL ("main.erl") = "Erlang", "erl -> Erlang");
         R.Check (EL ("main.hrl") = "Erlang", "hrl -> Erlang");
         R.Check (EL ("main.clj") = "Clojure", "clj -> Clojure");
         R.Check (EL ("main.cljs") = "Clojure", "cljs -> Clojure");
         R.Check (EL ("main.dart") = "Dart", "dart -> Dart");
         R.Check (EL ("script.sh") = "Shell", "sh -> Shell");
         R.Check (EL ("script.bash") = "Shell", "bash -> Shell");
         R.Check (EL ("script.ps1") = "PowerShell", "ps1 -> PowerShell");
         R.Check (EL ("query.sql") = "SQL", "sql -> SQL");
         R.Check (EL ("main.f") = "Fortran", "f -> Fortran");
         R.Check (EL ("main.f90") = "Fortran", "f90 -> Fortran");
         R.Check (EL ("main.f95") = "Fortran", "f95 -> Fortran");
         R.Check (EL ("main.f03") = "Fortran", "f03 -> Fortran");
         R.Check (EL ("main.s") = "Assembly", "s -> Assembly");
         R.Check (EL ("main.asm") = "Assembly", "asm -> Assembly");
         R.Check (EL ("script.r") = "R", "r -> R");
         R.Check (EL ("main.jl") = "Julia", "jl -> Julia");
         R.Check (EL ("main.zig") = "Zig", "zig -> Zig");
         R.Check (EL ("main.vhd") = "VHDL", "vhd -> VHDL");
         R.Check (EL ("main.vhdl") = "VHDL", "vhdl -> VHDL");
         R.Check (EL ("script.tcl") = "Tcl", "tcl -> Tcl");
         R.Check (EL ("noext") = "", "no extension -> empty");
         R.Check (EL ("noext.") = "", "trailing dot -> empty");
         R.Check (EL (".hidden") = "", "hidden no-name -> empty");
         R.Check (EL ("a.unknown") = "", "unknown extension -> empty");
      end;

      --  Test-scope dependencies: crates declared under a
      --  [[test-depends-on]] section of alire.toml or alire-dev.toml are
      --  classified Scope_Test.  Base deps stay base.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_Dep_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testdep_fixture",
            "obj/sbom_testdep_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-dep manifest graph success");
         R.Check (Count_Name (Graph, "testbase") = 1, "testbase registered");
         R.Check (Count_Name (Graph, "testrun") = 1, "testrun registered");
         R.Check (Count_Name (Graph, "devtest") = 1, "devtest registered");
         C := Find_Name (Graph, "testbase");
         R.Check (C.Scope = Scope_Base, "testbase scope = base");
         C := Find_Name (Graph, "testrun");
         R.Check (C.Scope = Scope_Test, "testrun scope = test");
         C := Find_Name (Graph, "devtest");
         R.Check
           (C.Scope = Scope_Test,
            "devtest scope = test (declared in dev manifest)");
      end;

      --  Test-GPR dependencies: a library with-claused only from a test
      --  project file (a .gpr under tests/) is classified Scope_Test.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         C       : Component_Info;
      begin
         Make_Test_GPR_Fixture;
         Adacovex.Parsers.Manifest.Build_Dependency_Graph
           ("obj/sbom_testgpr_fixture",
            "obj/sbom_testgpr_fixture/alire.toml",
            Graph,
            Success);
         R.Check (Success, "test-gpr manifest graph success");
         R.Check
           (Count_Name (Graph, "test_suite") = 1,
            "test_suite harness project registered");
         C := Find_Name (Graph, "test_suite");
         R.Check
           (C.Scope = Scope_Base, "test_suite (root with-clause) = base");
         R.Check
           (Count_Name (Graph, "libt") = 1,
            "libt registered (with-claused by test harness)");
         C := Find_Name (Graph, "libt");
         R.Check (C.Scope = Scope_Test, "libt scope = test (test GPR)");
         R.Check
           (C.PURL_Len = 12 and C.PURL (1 .. 12) = "pkg:gpr/libt",
            "libt purl");
      end;

      --  Scope_Property maps every scope (including test) to its SBOM
      --  property value.
      R.Check (Scope_Property (Scope_Test) = "test", "scope test -> test");
      R.Check
        (Scope_Property (Scope_System) = "system", "scope system -> system");
      R.Check
        (Scope_Property (Scope_Vendored) = "vendored",
         "scope vendored -> vendored");
   end Run;

end Adacovex_SBOM_Tests;
