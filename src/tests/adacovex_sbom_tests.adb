with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Parsers.Manifest;
with Adacovex.Renderers.SBOM; use Adacovex.Renderers.SBOM;

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

      --  CycloneDX 1.5 JSON rendering.
      declare
         Graph   : Component_Vectors.Vector;
         Success : Boolean := False;
         S       : constant String := "obj/sbom_test/cdx.json";
      begin
         Make_Demo_Graph (Graph);
         Write_SBOM (CycloneDX_JSON, S, Graph, "Platinum", "DAL-A", Success);
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
            R.Check (Contains (T, "adacovex:dal_target"), "cdx dal property");
            R.Check (Contains (T, "DAL-A"), "cdx dal value");
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
         Write_SBOM (SPDX_JSON, S, Graph, "Platinum", "DAL-C", Success);
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
              (Contains (T, "adacovex:dal_target=DAL-C"), "spdx dal attr");
            R.Check (Quotes_Balanced (T), "spdx quotes balanced");
            R.Check (Braces_Balanced (T), "spdx braces balanced");
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
         Write_SBOM (CycloneDX_JSON, S, Graph, "Gold", "DAL-B", Success);
         R.Check (Success, "escaped-json written");
         R.Check
           (Quotes_Balanced (Read_All (S)), "escaped-json quotes balanced");
      end;
   end Run;

end Adacovex_SBOM_Tests;
