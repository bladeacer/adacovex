with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adacovex;

package body Adacovex.Renderers.SBOM is

   use type Types.SPARK_Level;
   use type Types.Component_Kind;

   function Proof_Level_Property (Level : Types.SPARK_Level) return String
   with SPARK_Mode => On
   is
   begin
      --  Report the honest assessed level (Stone..Platinum).  The proof-level
      --  property must never overstate certainty: a lower level (e.g. Silver
      --  with unproved VCs) is reported verbatim rather than collapsed into a
      --  coarse "Gold", so SBOM consumers see the real assurance state.
      return Types.To_String (Level);
   end Proof_Level_Property;

   --  Proof level reported for dependency components.  adacovex only
   --  proves the target project itself; vendored/third-party dependencies
   --  are not audited, so they must never claim a Gold/Platinum level.
   Not_Proved : constant String := "Not proved";

   function DAL_Property_Value (Level : Types.DAL_Level) return String
   with SPARK_Mode => On
   is
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

   --  Map a dependency scope to the adacovex:dep_scope property value.
   --  Base dependencies are declared in the publishing manifest, dev
   --  dependencies only in the dev manifest, transitive ones in neither,
   --  and vendored packages are overlaid by a .adacovex/patches/ patch.
   --  @param Scope  Component dependency scope.
   --  @return "base", "dev", "transitive", or "vendored".
   function Scope_Property (Scope : Types.Component_Scope) return String
   with SPARK_Mode => On
   is
   begin
      case Scope is
         when Types.Scope_Base       =>
            return "base";

         when Types.Scope_Dev        =>
            return "dev";

         when Types.Scope_Transitive =>
            return "transitive";

         when Types.Scope_Vendored   =>
            return "vendored";
      end case;
   end Scope_Property;

   --  Escape a string for inclusion in a JSON document.  Backslash, quote
   --  and control characters are escaped so the emitted JSON is always
   --  well-formed, even for manifest strings containing embedded quotes.
   --  The output buffer is bounded at six bytes per input byte (the widest
   --  escape, "\u00xx").  Input length is capped at Max_Esc_Src so the
   --  6x output bound stays provably within Natural.
   --  @param S  String to escape.
   --  @return The escaped JSON string.
   --  Escape a string for inclusion in a JSON document.  Backslash, quote
   --  and control characters are escaped so the emitted JSON is always
   --  well-formed, even for manifest strings containing embedded quotes.
   --  The output buffer is bounded at six bytes per input byte (the widest
   --  escape, "\u00xx"), so the source length is preconditioned to keep the
   --  buffer bound within Natural.
   function Escape_JSON (S : String) return String is
      Buf : String (1 .. 6 * S'Length) := (others => ' ');
      Len : Natural := 0;
      Hex : constant String := "0123456789abcdef";
   begin
      for I in S'Range loop
         pragma Loop_Invariant (Len <= (I - S'First) * 6);
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

   --  Decimal string of a non-negative integer.  A fixed 10-character buffer
   --  holds any Natural (up to 2,147,483,647, ten digits); the loop invariant
   --  proves the write cursor never underflows the buffer.
   function I2S (N : Natural) return String with SPARK_Mode => On is
      Pow10 : constant array (1 .. 10) of Long_Long_Integer :=
        (10,
         100,
         1_000,
         10_000,
         100_000,
         1_000_000,
         10_000_000,
         100_000_000,
         1_000_000_000,
         10_000_000_000);
      Buf   : String (1 .. 10) := (others => '0');
      I     : Positive := 10;
      R     : Natural := N;
   begin
      if N = 0 then
         return "0";
      end if;
      while R > 0 loop
         pragma Loop_Invariant (I in 1 .. 10);
         pragma Loop_Invariant (Long_Long_Integer (R) < Pow10 (I));
         pragma Loop_Variant (Decreases => I);
         Buf (I) := Character'Val (Character'Pos ('0') + (R mod 10));
         R := R / 10;
         exit when R = 0;
         I := I - 1;
      end loop;
      return Buf (I .. 10);
   end I2S;
   function Pad2 (N : Natural) return String with SPARK_Mode => On is
   begin
      if N < 10 then
         return "0" & I2S (N);
      else
         return I2S (N);
      end if;
   end Pad2;

   --  ISO 8601 UTC timestamp from a Unix epoch second count, computed with
   --  pure integer arithmetic so the result is identical on every machine
   --  and timezone.  The civil date is extracted by bounded iteration over
   --  years and months (the epoch span is under ~70 years), so every bound
   --  is discharged with constant-coefficient arithmetic.
   function ISO_From_Epoch (Epoch_Sec : Natural) return String
   with SPARK_Mode => On
   is
      function Is_Leap (Y : Natural) return Boolean
      is ((Y mod 4 = 0 and then Y mod 100 /= 0) or else Y mod 400 = 0)
      with Global => null;

      function Days_In_Year (Y : Natural) return Natural
      is (if Is_Leap (Y) then 366 else 365)
      with Global => null;

      function Days_In_Month (M : Natural) return Natural
      is (case M is
            when 2              => 28,
            when 4 | 6 | 9 | 11 => 30,
            when others         => 31)
      with Post => Days_In_Month'Result in 28 .. 31, Global => null;

      Days     : constant Natural := Epoch_Sec / 86_400;
      Din      : Natural := Days;
      Sec      : Natural := Epoch_Sec mod 86_400;
      Yr       : Natural := 1970;
      Mo       : Natural := 1;
      Dy       : Natural := 1;
      Is_Feb29 : Boolean := False;
   begin
      pragma Assert (Days <= 24_855);
      for YI in 1 .. 68 loop
         pragma Loop_Invariant (Yr = 1969 + YI);
         pragma Loop_Invariant (Days - Din >= 365 * (YI - 1));
         exit when Din < Days_In_Year (Yr);
         Din := Din - Days_In_Year (Yr);
         Yr := 1970 + YI;
      end loop;
      pragma Assert (Din < 366);
      declare
         Leap : constant Boolean := Is_Leap (Yr);
      begin
         if Leap and then Din = 59 then
            Is_Feb29 := True;
            Din := 58;
         elsif Leap and then Din > 59 then
            Din := Din - 1;
         end if;
      end;
      pragma Assert (Din < 365);
      Mo := 1;
      while Mo < 12 and then Din >= Days_In_Month (Mo) loop
         pragma Loop_Invariant (Din < 365);
         pragma Loop_Variant (Decreases => Din);
         Din := Din - Days_In_Month (Mo);
         Mo := Mo + 1;
      end loop;
      pragma Assert (Din < 31);
      Dy := Din + 1;
      if Is_Feb29 then
         Dy := Dy + 1;
      end if;
      declare
         YrS : constant String := I2S (Yr);
         MoS : constant String := Pad2 (Mo);
         DyS : constant String := Pad2 (Dy);
         HrS : constant String := Pad2 (Sec / 3_600);
         MiS : constant String := Pad2 ((Sec mod 3_600) / 60);
         SdS : constant String := Pad2 (Sec mod 60);
      begin
         pragma Assert (YrS'Length <= 10);
         pragma Assert (MoS'Length <= 11);
         pragma Assert (DyS'Length <= 11);
         pragma Assert (HrS'Length <= 11);
         pragma Assert (MiS'Length <= 11);
         pragma Assert (SdS'Length <= 11);
         pragma
           Assert
             (YrS'Length
                + MoS'Length
                + DyS'Length
                + HrS'Length
                + MiS'Length
                + SdS'Length
                + 5
                <= Natural'Last);
         return
           YrS & "-" & MoS & "-" & DyS & "T" & HrS & ":" & MiS & ":" & SdS;
      end;
   end ISO_From_Epoch;

   --  ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS).
   --  Honors the SOURCE_DATE_EPOCH environment variable (reproducible-builds
   --  convention): when set to a Unix epoch second count, the timestamp is
   --  derived from it (UTC, integer math) so SBOM output is byte-for-byte
   --  deterministic across runs and machines.  Otherwise the current local
   --  time is used.
   function ISO_Timestamp return String is
      use Ada.Calendar;
   begin
      if Ada.Environment_Variables.Exists ("SOURCE_DATE_EPOCH") then
         declare
            V  : constant String :=
              Ada.Environment_Variables.Value ("SOURCE_DATE_EPOCH");
            N  : Natural := 0;
            Ok : Boolean := V'Length > 0;
         begin
            for I in V'Range loop
               if V (I) in '0' .. '9' then
                  if N < Natural'Last / 10 then
                     N := N * 10 + Character'Pos (V (I)) - Character'Pos ('0');
                  else
                     Ok := False;
                     exit;
                  end if;
               else
                  Ok := False;
                  exit;
               end if;
            end loop;
            if Ok then
               return ISO_From_Epoch (N);
            end if;
         end;
      end if;

      declare
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
      end;
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
      JStr
        (F,
         (if C.Kind = Types.Root_Component then Proof_Level else Not_Proved));
      Raw (F, "}");
      if C.Kind = Types.Root_Component and DAL_Target'Length > 0 then
         Raw (F, ", {""name"": ""adacovex:dal_target"", ""value"": ");
         JStr (F, DAL_Target);
         Raw (F, "}");
      end if;
      if C.Kind = Types.Dependency_Component then
         Raw (F, ", {""name"": ""adacovex:dep_scope"", ""value"": ");
         JStr (F, Scope_Property (C.Scope));
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
      Raw
        (F,
         (if C.Kind = Types.Root_Component then Proof_Level else Not_Proved));
      Raw (F, """");
      if C.Kind = Types.Root_Component and DAL_Target'Length > 0 then
         Raw (F, ", ""adacovex:dal_target=");
         Raw (F, DAL_Target);
         Raw (F, """");
      end if;
      if C.Kind = Types.Dependency_Component then
         Raw (F, ", ""adacovex:dep_scope=");
         Raw (F, Scope_Property (C.Scope));
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

   procedure Write_Markdown_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String)
   is
      Root : Types.Implementation.Component_Info;
   begin
      if Integer (Graph.Length) = 0 then
         return;
      end if;
      Root := Graph (1);

      Raw (F, "# Software Bill of Materials");
      NL (F);
      Raw (F, "");
      NL (F);
      Raw (F, "Generated by adacovex v");
      Raw (F, Adacovex.Version);
      Raw (F, " -- proof-aware component inventory.");
      NL (F);
      NL (F);
      Raw (F, "## Root project");
      NL (F);
      NL (F);
      Raw (F, "| Field | Value |");
      NL (F);
      Raw (F, "|---|---|");
      NL (F);
      Raw (F, "| Name | ");
      Raw (F, Root.Name (1 .. Root.Name_Len));
      Raw (F, " |");
      NL (F);
      if Root.Version_Len > 0 then
         Raw (F, "| Version | ");
         Raw (F, Root.Version (1 .. Root.Version_Len));
         Raw (F, " |");
         NL (F);
      end if;
      Raw (F, "| PURL | `");
      Raw (F, Root.PURL (1 .. Root.PURL_Len));
      Raw (F, "` |");
      NL (F);
      if Root.License_Len > 0 then
         Raw (F, "| License | ");
         Raw (F, Root.License (1 .. Root.License_Len));
         Raw (F, " |");
         NL (F);
      end if;
      if Root.Description_Len > 0 then
         Raw (F, "| Description | ");
         Raw (F, Root.Description (1 .. Root.Description_Len));
         Raw (F, " |");
         NL (F);
      end if;
      Raw (F, "| adacovex:proof_level | ");
      Raw (F, Proof_Level);
      Raw (F, " |");
      NL (F);
      if DAL_Target'Length > 0 then
         Raw (F, "| adacovex:dal_target | ");
         Raw (F, DAL_Target);
         Raw (F, " |");
         NL (F);
      end if;

      if Integer (Graph.Length) > 1 then
         NL (F);
         Raw (F, "## Dependencies");
         NL (F);
         NL (F);
         Raw
           (F,
            "| Component | Version | License | PURL | Scope | adacovex:proof_level");
         Raw (F, " |");
         NL (F);
         Raw (F, "|---|---|---|---|---|---");
         Raw (F, "|");
         NL (F);
         for I in 2 .. Integer (Graph.Length) loop
            declare
               C : Types.Implementation.Component_Info := Graph (I);
            begin
               Raw (F, "| ");
               Raw (F, C.Name (1 .. C.Name_Len));
               Raw (F, " | ");
               if C.Version_Len > 0 then
                  Raw (F, C.Version (1 .. C.Version_Len));
               end if;
               Raw (F, " | ");
               if C.License_Len > 0 then
                  Raw (F, C.License (1 .. C.License_Len));
               else
                  Raw (F, "NOASSERTION");
               end if;
               Raw (F, " | `");
               Raw (F, C.PURL (1 .. C.PURL_Len));
               Raw (F, "` | ");
               Raw (F, Scope_Property (C.Scope));
               Raw (F, " | ");
               Raw (F, Not_Proved);
               Raw (F, " |");
               NL (F);
            end;
         end loop;
      end if;

      NL (F);
      Raw (F, "_Automatic SBOM -- regenerate with `adacovex --target=.` (or");
      NL (F);
      Raw
        (F, "`adacovex sbom --format=md --target=.`). Do not edit manually._");
      NL (F);
   end Write_Markdown_To;

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

            when Types.Markdown       =>
               Write_Markdown_To (F, Graph, Proof_Level, DAL_Target);
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
