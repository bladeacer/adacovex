separate (Adacovex.Parsers.Manifest)
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
is
   C : Types.Implementation.Component_Info;
begin
   if Name'Length = 0 then
      return;
   end if;

   --  Keep one component when a dev-manifest dependency is also found as a
   --  system tool.  Store both scope facts on that component.
   for I in 1 .. Integer (Graph.Length) loop
      if Graph (I).Name_Len = Name'Length
        and then Graph (I).Name (1 .. Name'Length) = Name
      then
         C := Graph (I);
         if Scope = Types.Scope_System then
            C.Scope_Flags.Is_System := True;
            C.Scope_Flags.Is_Dev := True;
            C.Scope := Types.Scope_System;
         elsif Scope = Types.Scope_Dev then
            C.Scope_Flags.Is_Dev := True;
         elsif Scope = Types.Scope_Test then
            --  A test-only declaration is the most specific fact about the
            --  dependency: it wins over a base/dev/transitive label already
            --  on the component.
            C.Scope := Types.Scope_Test;
         end if;
         Graph (I) := C;
         return;
      end if;
   end loop;

   Set_Field (C.Name, C.Name_Len, Name);
   Set_Field (C.Version, C.Version_Len, Version);
   Set_Field (C.License, C.License_Len, License);
   Set_Path (C.Description, C.Description_Len, Desc);
   Set_Path (C.PURL, C.PURL_Len, PURL);
   Set_Path (C.Ref, C.Ref_Len, PURL);
   Set_Path (C.Website, C.Website_Len, Website);
   Set_Field (C.Language, C.Language_Len, Language);
   C.Kind := Types.Dependency_Component;
   C.Parent := Parent;
   C.From_GPR := From_GPR;
   C.Scope := Scope;
   C.Scope_Flags.Is_Dev :=
     Scope = Types.Scope_Dev or else Scope = Types.Scope_System;
   C.Scope_Flags.Is_System := Scope = Types.Scope_System;
   Graph.Append (C);
end Append_Dependency;
