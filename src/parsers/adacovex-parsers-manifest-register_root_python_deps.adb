separate (Adacovex.Parsers.Manifest)
--  Register the project root's Python requirements (requirements*.txt at
--  the target root) as dev-scope pypi dependencies of the root.  The SBOM
--  then names the actual packages (sphinx, myst-parser, ...) instead of a
--  generic system tool, with a proper pkg:pypi PURL.  The version pinned
--  in the requirements line wins; otherwise (or to enrich) the package
--  registry is asked via the pypi resolver row (`pip index versions`).
--  A missing pip, an offline machine, or an unknown package keeps the
--  name-only entry -- no licence or version is ever guessed.
procedure Register_Root_Python_Deps
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   T      : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Reqs   : Req_Vectors.Vector;
   Found  : Boolean := False;
   R_Path : String (1 .. Types.Max_Path);
   R_Len  : Natural := 0;
begin
   --  First requirements*.txt at the project root (a fixed name wins; the
   --  glob is the fallback, matching Read_Vendor_Manifest's behaviour).
   if Exists (T & "/requirements.txt") then
      declare
         P : constant String := T & "/requirements.txt";
      begin
         R_Len := P'Length;
         for I in P'Range loop
            R_Path (I - P'First + 1) := P (I);
         end loop;
      end;
      Found := True;
   else
      declare
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
      begin
         Start_Search (Search, T, "requirements*.txt");
         while not Found and then More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            if Kind (Ent) = Ordinary_File then
               declare
                  P : constant String := Full_Name (Ent);
               begin
                  if P'Length <= R_Path'Last then
                     R_Len := P'Length;
                     for I in P'Range loop
                        R_Path (I - P'First + 1) := P (I);
                     end loop;
                     Found := True;
                  end if;
               end;
            end if;
         end loop;
         End_Search (Search);
      exception
         when others =>
            null;
      end;
   end if;

   if not Found or else R_Len = 0 then
      return;
   end if;

   Collect_Req_Entries (R_Path (1 .. R_Len), Reqs);
   for I in 1 .. Integer (Reqs.Length) loop
      declare
         N    : constant String := Reqs (I).Name (1 .. Reqs (I).Len);
         V    : constant String := Reqs (I).Ver (1 .. Reqs (I).VLen);
         Lic  : Types.Desc_Field;
         L_Ln : Natural := 0;
         Vb   : Types.Desc_Field;
         V_Ln : Natural := 0;
         Web  : Types.Path_Field;
         W_Ln : Natural := 0;
      begin
         --  The registry fills the gaps the requirements line leaves: the
         --  resolved latest version when none is pinned, and the licence
         --  and website when the resolver's CLI answers.
         Resolve_Ecosystem_Metadata
           (T, "pypi", N, Lic, L_Ln, Vb, V_Ln, Web, W_Ln);
         declare
            Ver   : constant String :=
              (if V'Length > 0
               then V
               elsif V_Ln > 0
               then Vb (1 .. V_Ln)
               else "");
            Lic_S : constant String :=
              (if L_Ln > 0 then Lic (1 .. L_Ln) else "");
            Web_S : constant String :=
              (if W_Ln > 0 then Web (1 .. W_Ln) else "");
         begin
            Append_Dependency
              (Graph,
               N,
               Ver,
               Lic_S,
               "Python package referenced by the project (requirements.txt)",
               "pkg:pypi/" & N & (if Ver'Length > 0 then "@" & Ver else ""),
               1,
               False,
               Types.Scope_Dev,
               "Python",
               Web_S);
         end;
      end;
   end loop;
end Register_Root_Python_Deps;
