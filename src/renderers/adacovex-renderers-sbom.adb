with Ada.Calendar;
with Ada.Directories;
with Ada.Text_IO;
with Adacovex;

package body Adacovex.Renderers.SBOM is

   use type Types.SPARK_Level;
   use type Types.Component_Kind;

   function Proof_Level_Property (Level : Types.SPARK_Level) return String is
   begin
      if Level = Types.Platinum then
         return "Platinum";
      end if;
      return "Gold";
   end Proof_Level_Property;

   function DAL_Property_Value (Level : Types.DAL_Level) return String is
   begin
      case Level is
         when Types.DAL_A =>
            return "DAL-A";

         when Types.DAL_B =>
            return "DAL-B";

         when Types.DAL_C =>
            return "DAL-C";

         when Types.DAL_D =>
            return "DAL-D";

         when Types.DAL_E =>
            return "";
      end case;
   end DAL_Property_Value;

   --  Escape a string for inclusion in a JSON document.  Backslash, quote
   --  and control characters are escaped so the emitted JSON is always
   --  well-formed, even for manifest strings containing embedded quotes.
   function Escape_JSON (S : String) return String is
      Buf : String (1 .. S'Length * 6);
      Len : Natural := 0;
      Hex : constant String := "0123456789abcdef";
   begin
      for I in S'Range loop
         case S (I) is
            when '"'                                      =>
               Buf (Len + 1) := '\';
               Buf (Len + 2) := '"';

               Len := Len + 2;

            when '\'                                      =>
               Buf (Len + 1 .. Len + 2) := "\\";

               Len := Len + 2;

            when Character'Val (8)                        =>
               Buf (Len + 1 .. Len + 2) := "\b";

               Len := Len + 2;

            when Character'Val (12)                       =>
               Buf (Len + 1 .. Len + 2) := "\f";

               Len := Len + 2;

            when Character'Val (10)                       =>
               Buf (Len + 1 .. Len + 2) := "\n";

               Len := Len + 2;

            when Character'Val (13)                       =>
               Buf (Len + 1 .. Len + 2) := "\r";

               Len := Len + 2;

            when Character'Val (9)                        =>
               Buf (Len + 1 .. Len + 2) := "\t";

               Len := Len + 2;

            when Character'Val (0) .. Character'Val (7)
               | Character'Val (11)
               | Character'Val (14) .. Character'Val (31) =>
               declare
                  C : constant Natural := Character'Pos (S (I));
               begin
                  Buf (Len + 1 .. Len + 6) :=
                    "\u00" & Hex (C / 16 + 1) & Hex (C mod 16 + 1);
                  Len := Len + 6;
               end;

            when others                                   =>
               Len := Len + 1;
               Buf (Len) := S (I);
         end case;
      end loop;
      return Buf (1 .. Len);
   end Escape_JSON;

   procedure Raw (F : in out Ada.Text_IO.File_Type; S : String) is
   begin
      Ada.Text_IO.Put (F, S);
   end Raw;

   procedure NL (F : in out Ada.Text_IO.File_Type) is
   begin
      Ada.Text_IO.New_Line (F);
   end NL;

   procedure JStr (F : in out Ada.Text_IO.File_Type; S : String) is
   begin
      Raw (F, """");
      Raw (F, Escape_JSON (S));
      Raw (F, """");
   end JStr;

   function I2S (N : Natural) return String is
      Buf : String (1 .. 10);
      Pos : Natural := 10;
      R   : Natural := N;
   begin
      if N = 0 then
         return "0";
      end if;
      while R > 0 loop
         Buf (Pos) := Character'Val (Character'Pos ('0') + (R mod 10));
         R := R / 10;
         exit when R = 0;
         Pos := Pos - 1;
      end loop;
      return Buf (Pos .. 10);
   end I2S;

   --  Local-time ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS).
   function ISO_Timestamp return String is
      use Ada.Calendar;
      Now      : constant Time := Clock;
      Yr       : Year_Number;
      Mo       : Month_Number;
      Dy       : Day_Number;
      Sec      : Day_Duration;
      H, M, Sd : Natural;
   begin
      Split (Now, Yr, Mo, Dy, Sec);
      H := Integer (Sec) / 3600;
      M := (Integer (Sec) mod 3600) / 60;
      Sd := Integer (Sec) mod 60;

      return
        I2S (Natural (Yr))
        & "-"
        & (if Mo < 10 then "0" else "")
        & I2S (Natural (Mo))
        & "-"
        & (if Dy < 10 then "0" else "")
        & I2S (Natural (Dy))
        & "T"
        & (if H < 10 then "0" else "")
        & I2S (H)
        & ":"
        & (if M < 10 then "0" else "")
        & I2S (M)
        & ":"
        & (if Sd < 10 then "0" else "")
        & I2S (Sd);
   end ISO_Timestamp;

   --  Emit a single CycloneDX component object.  Used for the root component
   --  in metadata and for every dependency in the components array.
   procedure Write_CDX_Component
     (F           : in out Ada.Text_IO.File_Type;
      C           : Types.Implementation.Component_Info;
      Proof_Level : String;
      DAL_Target  : String;
      Indent      : String;
      First_Field : in out Boolean)
   is
      procedure Fld (Key, Val : String; Quoted : Boolean) is
      begin
         if not First_Field then
            Raw (F, ",");
         end if;
         NL (F);
         Raw (F, Indent);
         JStr (F, Key);
         Raw (F, ": ");
         if Quoted then
            JStr (F, Val);
         else
            Raw (F, Val);
         end if;
         First_Field := False;
      end Fld;
   begin
      Raw (F, "{");
      Fld
        ("type",
         (if C.Kind = Types.Root_Component then "application" else "library"),
         True);
      Fld ("bom-ref", C.Ref (1 .. C.Ref_Len), True);
      Fld ("name", C.Name (1 .. C.Name_Len), True);
      if C.Version_Len > 0 then
         Fld ("version", C.Version (1 .. C.Version_Len), True);
      end if;
      if C.PURL_Len > 0 then
         Fld ("purl", C.PURL (1 .. C.PURL_Len), True);
      end if;
      if C.License_Len > 0 then
         if not First_Field then
            Raw (F, ",");
         end if;
         NL (F);
         Raw (F, Indent);
         JStr (F, "licenses");
         Raw (F, ": [{""license"": {""id"": ");
         JStr (F, C.License (1 .. C.License_Len));
         Raw (F, "}}]");
         First_Field := False;
      end if;
      if C.Description_Len > 0 then
         Fld ("description", C.Description (1 .. C.Description_Len), True);
      end if;
      if not First_Field then
         Raw (F, ",");
      end if;
      NL (F);
      Raw (F, Indent);
      JStr (F, "properties");
      Raw (F, ": [{""name"": ""adacovex:proof_level"", ""value"": ");
      JStr (F, Proof_Level);
      Raw (F, "}");
      if DAL_Target'Length > 0 then
         Raw (F, ", {""name"": ""adacovex:dal_target"", ""value"": ");
         JStr (F, DAL_Target);
         Raw (F, "}");
      end if;
      Raw (F, "]");
      First_Field := False;
      NL (F);
      Raw (F, Indent);
      Raw (F, "}");
   end Write_CDX_Component;

   --  Emit the CycloneDX dependencies section: every component that has at
   --  least one child lists its children in dependsOn.
   procedure Write_CDX_Dependencies
     (F     : in out Ada.Text_IO.File_Type;
      Graph : Types.Implementation.Component_Vectors.Vector)
   is
      First_Dep : Boolean := True;
   begin
      for I in 1 .. Integer (Graph.Length) loop
         declare
            Child_Ct : Natural := 0;
         begin
            for J in 1 .. Integer (Graph.Length) loop
               if Graph (J).Parent = I then
                  Child_Ct := Child_Ct + 1;
               end if;
            end loop;
            if Child_Ct > 0 then
               if not First_Dep then
                  Raw (F, ",");
               end if;
               First_Dep := False;
               NL (F);
               Raw (F, "    {");
               NL (F);
               Raw (F, "      ""ref"": ");
               JStr (F, Graph (I).Ref (1 .. Graph (I).Ref_Len));
               Raw (F, ",");
               NL (F);
               Raw (F, "      ""dependsOn"": [");
               declare
                  First_Child : Boolean := True;
               begin
                  for J in 1 .. Integer (Graph.Length) loop
                     if Graph (J).Parent = I then
                        if not First_Child then
                           Raw (F, ", ");
                        end if;
                        First_Child := False;
                        JStr (F, Graph (J).Ref (1 .. Graph (J).Ref_Len));
                     end if;
                  end loop;
               end;
               Raw (F, "]");
               NL (F);
               Raw (F, "    }");
            end if;
         end;
      end loop;
      if First_Dep then
         --  No relationships: emit an empty array.
         null;
      end if;
   end Write_CDX_Dependencies;

   procedure Write_CycloneDX_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String)
   is
      Root         : Types.Implementation.Component_Info;
      First_Field  : Boolean := True;
      First_Comp   : Boolean := True;
      Tool_Version : constant String := Adacovex.Version;
   begin
      if Integer (Graph.Length) = 0 then
         return;
      end if;
      Root := Graph (1);

      Raw (F, "{");
      NL (F);
      Raw (F, "  ""bomFormat"": ""CycloneDX"",");
      NL (F);
      Raw (F, "  ""specVersion"": ""1.5"",");
      NL (F);
      Raw (F, "  ""version"": 1,");
      NL (F);
      Raw (F, "  ""metadata"": {");
      NL (F);
      Raw (F, "    ""timestamp"": ");
      JStr (F, ISO_Timestamp);
      Raw (F, ",");
      NL (F);
      Raw (F, "    ""tools"": [");
      NL (F);
      Raw
        (F,
         "      {""vendor"": ""bladeacer"", ""name"": ""adacovex"", ""version"": ");
      JStr (F, Tool_Version);
      Raw (F, "}");
      NL (F);
      Raw (F, "    ],");
      NL (F);
      Raw (F, "    ""component"": ");
      Write_CDX_Component
        (F, Root, Proof_Level, DAL_Target, "      ", First_Field);
      NL (F);
      Raw (F, "  },");

      --  components array (dependencies only; the root lives in metadata)
      NL (F);
      Raw (F, "  ""components"": [");
      for I in 2 .. Integer (Graph.Length) loop
         declare
            C : Types.Implementation.Component_Info := Graph (I);
         begin
            if not First_Comp then
               Raw (F, ",");
            end if;
            First_Comp := False;
            NL (F);
            Raw (F, "    ");
            First_Field := True;
            Write_CDX_Component
              (F, C, Proof_Level, DAL_Target, "      ", First_Field);
         end;
      end loop;
      NL (F);
      Raw (F, "  ],");

      --  dependencies section
      NL (F);
      Raw (F, "  ""dependencies"": [");
      Write_CDX_Dependencies (F, Graph);
      NL (F);
      Raw (F, "  ]");

      NL (F);
      Raw (F, "}");
      NL (F);
   end Write_CycloneDX_To;

   --  Emit a single SPDX package object.
   procedure Write_SPDX_Package
     (F           : in out Ada.Text_IO.File_Type;
      C           : Types.Implementation.Component_Info;
      Index       : Natural;
      Proof_Level : String;
      DAL_Target  : String;
      First_Pkg   : in out Boolean)
   is
      License : constant String :=
        (if C.License_Len > 0
         then C.License (1 .. C.License_Len)
         else "NOASSERTION");
   begin
      if not First_Pkg then
         Raw (F, ",");
      end if;
      First_Pkg := False;
      NL (F);
      Raw (F, "    {");
      NL (F);
      Raw (F, "      ""SPDXID"": ""SPDXRef-Package-");
      Raw (F, I2S (Index));
      Raw (F, """,");
      NL (F);
      Raw (F, "      ""name"": ");
      JStr (F, C.Name (1 .. C.Name_Len));
      if C.Version_Len > 0 then
         Raw (F, ",");
         NL (F);
         Raw (F, "      ""versionInfo"": ");
         JStr (F, C.Version (1 .. C.Version_Len));
      end if;
      Raw (F, ",");
      NL (F);
      Raw (F, "      ""downloadLocation"": ""NOASSERTION"",");
      NL (F);
      Raw (F, "      ""filesAnalyzed"": false,");
      NL (F);
      Raw (F, "      ""licenseConcluded"": ");
      JStr (F, License);
      Raw (F, ",");
      NL (F);
      Raw (F, "      ""licenseDeclared"": ");
      JStr (F, License);
      Raw (F, ",");
      NL (F);
      Raw (F, "      ""copyrightText"": ""NOASSERTION"",");
      NL (F);
      Raw
        (F,
         "      ""externalRefs"": [{""referenceCategory"": ""PACKAGE-MANAGER"", "
         & """referenceType"": ""purl"", ""referenceLocator"": ");
      JStr (F, C.PURL (1 .. C.PURL_Len));
      Raw (F, "}],");
      NL (F);
      Raw (F, "      ""attributionTexts"": [""adacovex:proof_level=");
      Raw (F, Proof_Level);
      Raw (F, """");
      if DAL_Target'Length > 0 then
         Raw (F, ", ""adacovex:dal_target=");
         Raw (F, DAL_Target);
         Raw (F, """");
      end if;
      Raw (F, "]");
      NL (F);
      Raw (F, "    }");
   end Write_SPDX_Package;

   procedure Write_SPDX_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String)
   is
      Root      : Types.Implementation.Component_Info;
      First_Pkg : Boolean := True;
   begin
      if Integer (Graph.Length) = 0 then
         return;
      end if;
      Root := Graph (1);

      Raw (F, "{");
      NL (F);
      Raw (F, "  ""spdxVersion"": ""SPDX-2.3"",");
      NL (F);
      Raw (F, "  ""dataLicense"": ""CC0-1.0"",");
      NL (F);
      Raw (F, "  ""SPDXID"": ""SPDXRef-DOCUMENT"",");
      NL (F);
      Raw (F, "  ""name"": ");
      JStr (F, Root.Name (1 .. Root.Name_Len) & "-SBOM");
      Raw (F, ",");
      NL (F);
      Raw (F, "  ""documentNamespace"": ""https://spdx.org/spdxdocs/");
      Raw (F, Root.Name (1 .. Root.Name_Len));
      Raw (F, "-v");
      Raw (F, Adacovex.Version);
      Raw (F, """,");
      NL (F);
      Raw (F, "  ""creationInfo"": {");
      NL (F);
      Raw (F, "    ""created"": ");
      JStr (F, ISO_Timestamp);
      Raw (F, ",");
      NL (F);
      Raw (F, "    ""creators"": [""Tool: adacovex-");
      Raw (F, Adacovex.Version);
      Raw (F, """]");
      NL (F);
      Raw (F, "  },");

      NL (F);
      Raw (F, "  ""packages"": [");
      for I in 1 .. Integer (Graph.Length) loop
         declare
            C : Types.Implementation.Component_Info := Graph (I);
         begin
            Write_SPDX_Package (F, C, I, Proof_Level, DAL_Target, First_Pkg);
         end;
      end loop;
      NL (F);
      Raw (F, "  ],");

      NL (F);
      Raw (F, "  ""relationships"": [");
      NL (F);
      Raw
        (F,
         "    {""spdxElementId"": ""SPDXRef-DOCUMENT"", "
         & """relationshipType"": ""DESCRIBES"", "
         & """relatedSpdxElement"": ""SPDXRef-Package-1""}");
      for I in 2 .. Integer (Graph.Length) loop
         Raw (F, ",");
         NL (F);
         Raw (F, "    {""spdxElementId"": ""SPDXRef-Package-");
         Raw (F, I2S (Graph (I).Parent));
         Raw
           (F,
            """, ""relationshipType"": ""DEPENDS_ON"", "
            & """relatedSpdxElement"": ""SPDXRef-Package-");
         Raw (F, I2S (I));
         Raw (F, """}");
      end loop;
      NL (F);
      Raw (F, "  ]");

      NL (F);
      Raw (F, "}");
      NL (F);
   end Write_SPDX_To;

   procedure Write_SBOM
     (Format      : Types.SBOM_Format_Kind;
      Out_Path    : String;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String;
      Success     : out Boolean)
   is
      use Ada.Text_IO;
      F : File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Out_Path));
      begin
         Create (F, Out_File, Out_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         case Format is
            when Types.CycloneDX_JSON =>
               Write_CycloneDX_To (F, Graph, Proof_Level, DAL_Target);

            when Types.SPDX_JSON      =>
               Write_SPDX_To (F, Graph, Proof_Level, DAL_Target);
         end case;
      exception
         when others =>
            Close (F);
            Success := False;
            return;
      end;

      Close (F);
      Success := True;
   end Write_SBOM;

end Adacovex.Renderers.SBOM;
