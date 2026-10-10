separate (Adacovex.Parsers.Manifest)
--  Whether to scan a file for tool references. Only dev-facing build
--  files are scanned: Makefile variants (by name), build manifests
--  (package.json, Cargo.toml, go.mod, pyproject.toml, ...), shell
--  scripts, GNAT project files, and CI workflows. Source files are
--  deliberately excluded -- scanning them produces false positives
--  (identifiers like "ada", "go", "make" collide with tool names) and
--  they never invoke build tools by name.
--  @param Name  File base name.
--  @return True when the file drives a build.
function Should_Scan (Name : String) return Boolean is
   Dot : Natural := 0;
begin
   if Name = "makefile" or else Name = "Makefile" or else Name = "GNUmakefile"
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
