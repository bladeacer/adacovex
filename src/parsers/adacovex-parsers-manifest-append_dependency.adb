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
   if Name'Length = 0 or else Name_In_Graph (Graph, Name) then
      return;
   end if;
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
   Graph.Append (C);
end Append_Dependency;
