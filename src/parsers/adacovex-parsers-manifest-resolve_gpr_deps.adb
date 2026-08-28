separate (Adacovex.Parsers.Manifest)
--  Resolve GPR with-clause dependencies into the graph.  Deps already
--  present in the graph are skipped.  Transitive GPR dependencies are
--  resolved by parsing the referenced .gpr file (if it lives in the
--  project tree), up to a bounded depth to guard against cycles.
--  A dependency with-claused only from a test project file (a .gpr under a
--  tests/ test/ or t/ directory, or a test-named project such as
--  test_runner.gpr) is classified Scope_Test.  The test classification
--  propagates to everything the test project pulls in transitively.
procedure Resolve_GPR_Deps
  (Graph         : in out Types.Implementation.Component_Vectors.Vector;
   GPR_Files     : Path_Vectors.Vector;
   Deps          : Name_Vectors.Vector;
   Parent        : Natural;
   Depth         : Natural;
   From_Test_GPR : Boolean := False)
is

   --  Whether a .gpr file is a test project file: its containing directory
   --  is named tests, test, or t, or its project base name carries a test
   --  marker (test_runner, lib_tests, ..._test, tests).
   function Is_Test_GPR_Path (Path : String) return Boolean is
      Base  : constant String := Ada.Directories.Simple_Name (Path);
      Dot   : Natural := 0;
      Stem  : String (1 .. 128) := (others => ' ');
      SLen  : Natural := 0;
      Dir_N : constant String :=
        Ada.Directories.Simple_Name
          (Ada.Directories.Containing_Directory (Path));
   begin
      if Dir_N = "tests" or else Dir_N = "test" or else Dir_N = "t" then
         return True;
      end if;
      for I in reverse Base'Range loop
         if Base (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot > Base'First then
         SLen := Dot - Base'First;
         if SLen > Stem'Last then
            SLen := Stem'Last;
         end if;
         Stem (1 .. SLen) := Base (Base'First .. Base'First + SLen - 1);
      end if;
      return
        (SLen = 4 and then Stem (1 .. 4) = "test")
        or else (SLen = 5 and then Stem (1 .. 5) = "tests")
        or else (SLen > 5 and then Stem (1 .. 5) = "test_")
        or else (SLen > 5 and then Stem (SLen - 4 .. SLen) = "_test")
        or else (SLen > 6 and then Stem (SLen - 5 .. SLen) = "_tests");
   end Is_Test_GPR_Path;

begin
   for I in 1 .. Integer (Deps.Length) loop
      declare
         Name : constant String := Deps (I).Name (1 .. Deps (I).Len);
      begin
         if not Name_In_Graph (Graph, Name) then
            declare
               S : Types.Component_Scope := Classify_Scope (Name);
            begin
               --  A dependency with-claused only from a test project file is
               --  a test dependency.  A GPR with-clause dependency of the
               --  root project is a direct build dependency (base).  The
               --  exception is a dependency named in a manifest.
               --  Classify_Scope already decided those.  Deeper with-clauses
               --  are transitive.
               if S = Types.Scope_Transitive and then From_Test_GPR then
                  S := Types.Scope_Test;
               elsif S = Types.Scope_Transitive and then Parent = 1 then
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
                          (Graph,
                           GPR_Files,
                           Sub_Deps,
                           C_Index,
                           Depth - 1,
                           Is_Test_GPR_Path (GPR_Path (1 .. GPR_Len)));
                     end;
                  end if;
               end;
            end if;
         end if;
      end;
   end loop;
end Resolve_GPR_Deps;
