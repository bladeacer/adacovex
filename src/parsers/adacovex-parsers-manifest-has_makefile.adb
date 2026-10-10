separate (Adacovex.Parsers.Manifest)
--  Whether the project root holds a Makefile variant, which implies make
--  even when no recipe spells out the driver by name.
--  @param Target_Dir  Project root directory.
--  @return True when a Makefile, makefile, or GNUmakefile exists.
function Has_Makefile (Target_Dir : String) return Boolean is
begin
   return
     Ada.Directories.Exists (Target_Dir & "/Makefile")
     or else Ada.Directories.Exists (Target_Dir & "/makefile")
     or else Ada.Directories.Exists (Target_Dir & "/GNUmakefile");
end Has_Makefile;
