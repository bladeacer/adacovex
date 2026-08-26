separate (Adacovex.Parsers.Manifest)
--  Language name for a source file, derived from its extension.  The
--  extension is the source of truth.  A .py file is Python even when a
--  Cargo.toml sits next to it.  The manifest language only breaks ties.
--  @param Name  File base name (for example "a.py").
--  @return Language display name ("Python"), or "" for unknown.
function Extension_Language (Name : String) return String is
   Dot : Natural := 0;
   Ext : String (1 .. 8) := (others => ' ');
   EL  : Natural := 0;
begin
   for I in reverse Name'Range loop
      if Name (I) = '.' then
         Dot := I;
         exit;
      end if;
   end loop;
   if Dot = 0 or else Dot = Name'Last or else Name'Last - Dot > Ext'Last then
      return "";
   end if;
   EL := Name'Last - Dot;
   for I in 1 .. EL loop
      Ext (I) := Name (Dot + I);
   end loop;

   if Ext (1 .. EL) = "ads"
     or else Ext (1 .. EL) = "adb"
     or else Ext (1 .. EL) = "ada"
     or else Ext (1 .. EL) = "gpr"
   then
      return "Ada";
   elsif Ext (1 .. EL) = "js"
     or else Ext (1 .. EL) = "mjs"
     or else Ext (1 .. EL) = "cjs"
   then
      return "JavaScript";
   elsif Ext (1 .. EL) = "ts" or else Ext (1 .. EL) = "tsx" then
      return "TypeScript";
   elsif Ext (1 .. EL) = "css" then
      return "CSS";
   elsif Ext (1 .. EL) = "html" or else Ext (1 .. EL) = "htm" then
      return "HTML";
   elsif Ext (1 .. EL) = "py" then
      return "Python";
   elsif Ext (1 .. EL) = "go" then
      return "Go";
   elsif Ext (1 .. EL) = "rs" then
      return "Rust";
   elsif Ext (1 .. EL) = "c" or else Ext (1 .. EL) = "h" then
      return "C";
   elsif Ext (1 .. EL) = "cpp"
     or else Ext (1 .. EL) = "cc"
     or else Ext (1 .. EL) = "cxx"
     or else Ext (1 .. EL) = "hpp"
     or else Ext (1 .. EL) = "hh"
     or else Ext (1 .. EL) = "hxx"
   then
      return "C++";
   elsif Ext (1 .. EL) = "cs" then
      return "C#";
   elsif Ext (1 .. EL) = "java" then
      return "Java";
   elsif Ext (1 .. EL) = "rb" then
      return "Ruby";
   elsif Ext (1 .. EL) = "php" then
      return "PHP";
   elsif Ext (1 .. EL) = "swift" then
      return "Swift";
   elsif Ext (1 .. EL) = "kt" or else Ext (1 .. EL) = "kts" then
      return "Kotlin";
   elsif Ext (1 .. EL) = "scala" then
      return "Scala";
   elsif Ext (1 .. EL) = "ml" or else Ext (1 .. EL) = "mli" then
      return "OCaml";
   elsif Ext (1 .. EL) = "lua" then
      return "Lua";
   elsif Ext (1 .. EL) = "pl" then
      return "Perl";
   elsif Ext (1 .. EL) = "hs" then
      return "Haskell";
   elsif Ext (1 .. EL) = "ex" or else Ext (1 .. EL) = "exs" then
      return "Elixir";
   elsif Ext (1 .. EL) = "erl" or else Ext (1 .. EL) = "hrl" then
      return "Erlang";
   elsif Ext (1 .. EL) = "clj" or else Ext (1 .. EL) = "cljs" then
      return "Clojure";
   elsif Ext (1 .. EL) = "dart" then
      return "Dart";
   elsif Ext (1 .. EL) = "sh" or else Ext (1 .. EL) = "bash" then
      return "Shell";
   elsif Ext (1 .. EL) = "ps1" then
      return "PowerShell";
   elsif Ext (1 .. EL) = "sql" then
      return "SQL";
   elsif Ext (1 .. EL) = "f"
     or else Ext (1 .. EL) = "f90"
     or else Ext (1 .. EL) = "f95"
     or else Ext (1 .. EL) = "f03"
   then
      return "Fortran";
   elsif Ext (1 .. EL) = "s" or else Ext (1 .. EL) = "asm" then
      return "Assembly";
   elsif Ext (1 .. EL) = "r" then
      return "R";
   elsif Ext (1 .. EL) = "jl" then
      return "Julia";
   elsif Ext (1 .. EL) = "zig" then
      return "Zig";
   elsif Ext (1 .. EL) = "vhd" or else Ext (1 .. EL) = "vhdl" then
      return "VHDL";
   elsif Ext (1 .. EL) = "tcl" then
      return "Tcl";
   end if;
   return "";
end Extension_Language;
