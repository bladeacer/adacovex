separate (Adacovex.Parsers.Manifest)
--  Resolve GPR with-clause dependencies into the graph.  Deps already
--  present in the graph are skipped.  Transitive GPR dependencies are
--  resolved by parsing the referenced .gpr file (if it lives in the
--  project tree), up to a bounded depth to guard against cycles.
procedure Resolve_GPR_Deps
  (Graph     : in out Types.Implementation.Component_Vectors.Vector;
   GPR_Files : Path_Vectors.Vector;
   Deps      : Name_Vectors.Vector;
   Parent    : Natural;
   Depth     : Natural) is
begin
   for I in 1 .. Integer (Deps.Length) loop
      declare
         Name : constant String := Deps (I).Name (1 .. Deps (I).Len);
      begin
         if not Name_In_Graph (Graph, Name) then
            declare
               S : Types.Component_Scope := Classify_Scope (Name);
            begin
               --  A GPR with-clause dependency of the root project is a
               --  direct build dependency (base).  The exception is a
               --  dependency named in a manifest.  Classify_Scope already
               --  decided those.  Deeper with-clauses are transitive.
               if S = Types.Scope_Transitive and then Parent = 1 then
                  S := Types.Scope_Base;
               end if;
               Append_Dependency
                 (Graph,
                  Name,
                  "",
                  "",
                  "",
                  "pkg:gpr/" & Name,
                  Parent,
                  True,
                  S,
                  "Ada");
            end;
            if Depth > 0 then
               declare
                  GPR_Path : Types.Path_Field;
                  GPR_Len  : Natural := 0;
               begin
                  Find_GPR (GPR_Files, Name, GPR_Path, GPR_Len);
                  if GPR_Len > 0 then
                     declare
                        P_Name   : Types.Desc_Field;
                        P_Len    : Natural := 0;
                        Sub_Deps : Name_Vectors.Vector;
                        C_Index  : Natural := Natural (Graph.Length);
                     begin
                        Parse_GPR
                          (GPR_Path (1 .. GPR_Len), P_Name, P_Len, Sub_Deps);
                        Resolve_GPR_Deps
                          (Graph, GPR_Files, Sub_Deps, C_Index, Depth - 1);
                     end;
                  end if;
               end;
            end if;
         end if;
      end;
   end loop;
end Resolve_GPR_Deps;
