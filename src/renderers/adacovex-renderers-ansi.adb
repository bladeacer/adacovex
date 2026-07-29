with Ada.Text_IO;

package body Adacovex.Renderers.ANSI is

   use type Types.Test_Status;
   use type Types.DAL_Status;

   ESC : constant String := ASCII.ESC & "[";

   procedure Put_Color
     (Color : String; Bold : Boolean := False; Enable : Boolean := True) is
   begin
      if Enable then
         if Bold then
            Ada.Text_IO.Put (ESC & "1;" & Color & "m");
         else
            Ada.Text_IO.Put (ESC & Color & "m");
         end if;
      end if;
   end Put_Color;

   procedure Reset_Color (Enable : Boolean := True) is
   begin
      if Enable then
         Ada.Text_IO.Put (ESC & "0m");
      end if;
   end Reset_Color;

   procedure Render_Summary
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Vectors.Vector;
      Use_Color   : Boolean := False) is
   begin
      Ada.Text_IO.Put ("  scanning sources... ");
      Put_Color ("37", Enable => Use_Color);
      Ada.Text_IO.Put
        (Integer'Image (Integer (Packages.Length)) & " packages,");
      Ada.Text_IO.Put
        (Natural'Image (Doc_Metrics.Total_Subprograms) & " subprograms");
      Reset_Color (Enable => Use_Color);
      Ada.Text_IO.New_Line;

      --  Docstring coverage
      Ada.Text_IO.Put ("  docstrings: ");
      Ada.Text_IO.Put
        (Natural'Image (Doc_Metrics.Documented_Subprogs)
         & "/"
         & Natural'Image (Doc_Metrics.Total_Subprograms));
      if Doc_Metrics.Coverage_Pct >= 80 then
         Put_Color ("32", Enable => Use_Color);
      elsif Doc_Metrics.Coverage_Pct >= 50 then
         Put_Color ("33", Enable => Use_Color);
      else
         Put_Color ("31", Enable => Use_Color);
      end if;
      Ada.Text_IO.Put (" (" & Natural'Image (Doc_Metrics.Coverage_Pct) & "%)");
      Reset_Color (Enable => Use_Color);
      Ada.Text_IO.New_Line;

      --  SPARK proof
      Ada.Text_IO.Put ("  GNATprove: ");
      case Proof.Level is
         when Types.Platinum =>
            Put_Color ("37", Enable => Use_Color);

         when Types.Gold     =>
            Put_Color ("33", Enable => Use_Color);

         when Types.Silver   =>
            Put_Color ("37", Enable => Use_Color);

         when Types.Bronze   =>
            Put_Color ("31", Enable => Use_Color);

         when Types.Stone    =>
            Put_Color ("31", Enable => Use_Color);
      end case;
      Ada.Text_IO.Put (Types.To_String (Proof.Level));
      Reset_Color (Enable => Use_Color);
      Ada.Text_IO.Put (" (" & Natural'Image (Proof.Total_VCs) & " VCs");
      if Proof.Unproved > 0 then
         Ada.Text_IO.Put (", " & Natural'Image (Proof.Unproved) & " unproved");
      end if;
      if Proof.Justified > 0 then
         Ada.Text_IO.Put
           (", " & Natural'Image (Proof.Justified) & " justified");
      end if;
      Ada.Text_IO.Put (")");
      Ada.Text_IO.New_Line;

      --  Test results
      Ada.Text_IO.Put ("  tests: ");
      if Tests.Total_Failed = 0 then
         Put_Color ("32", Enable => Use_Color);
      else
         Put_Color ("31", Enable => Use_Color);
      end if;
      Ada.Text_IO.Put (Natural'Image (Tests.Total_Passed) & " passed,");
      Ada.Text_IO.Put (Natural'Image (Tests.Total_Failed) & " failed");
      Reset_Color (Enable => Use_Color);
      Ada.Text_IO.New_Line;

      --  DAL compliance
      Ada.Text_IO.Put
        ("  DAL-" & Types.To_String (DAL_Assess.Target_DAL) & ": ");
      if DAL_Assess.Status = Types.Achieved then
         Put_Color ("32", Bold => True, Enable => Use_Color);
      else
         Put_Color ("31", Bold => True, Enable => Use_Color);
      end if;
      Ada.Text_IO.Put (Types.To_String (DAL_Assess.Status));
      Reset_Color (Enable => Use_Color);
      Ada.Text_IO.New_Line;

      --  Undocumented subprograms (file:line format)
      declare
         UD_Count : Natural := 0;
      begin
         for P in 1 .. Integer (Packages.Length) loop
            for S in 1 .. Integer (Packages (P).Subprograms.Length) loop
               if not Packages (P).Subprograms (S).Has_Docstring then
                  if UD_Count = 0 then
                     Ada.Text_IO.New_Line;
                     Ada.Text_IO.Put_Line ("  undocumented subprograms:");
                  end if;
                  UD_Count := UD_Count + 1;
                  Ada.Text_IO.Put
                    ("    "
                     & Packages (P).File_Path (1 .. Packages (P).Path_Len));
                  Ada.Text_IO.Put
                    (":"
                     & Natural'Image
                         (Packages (P).Subprograms (S).Line_Number));
                  Ada.Text_IO.Put_Line
                    (": subprogram """
                     & Packages (P).Subprograms (S).Name
                         (1 .. Packages (P).Subprograms (S).Name_Len)
                     & """ is undocumented");
                  Ada.Text_IO.Put_Line
                    ("      help: add --  @param and/or --  @return "
                     & "docstring tags before the declaration");
               end if;
            end loop;
         end loop;
      end;

      --  Unproved VCs summary
      if Proof.Unproved > 0 then
         Ada.Text_IO.New_Line;
         Ada.Text_IO.Put_Line
           ("  unproved VCs: " & Natural'Image (Proof.Unproved) & " total");
         Ada.Text_IO.Put_Line
           ("    help: review gnatprove.out for individual VC locations");
      end if;
      if Proof.Justified > 0 then
         Ada.Text_IO.New_Line;
         Ada.Text_IO.Put_Line
           ("  justified VCs: " & Natural'Image (Proof.Justified) & " total");
         Ada.Text_IO.Put_Line
           ("    help: review gnatprove.out for justified VC locations");
      end if;

      --  DAL failures
      if not DAL_Assess.Failed_Reasons.Is_Empty then
         Ada.Text_IO.New_Line;
         Put_Color ("31", Enable => Use_Color);
         Ada.Text_IO.Put_Line
           ("  DAL-" & Types.To_String (DAL_Assess.Target_DAL) & " failures:");
         Reset_Color (Enable => Use_Color);
         for F in 1 .. Integer (DAL_Assess.Failed_Reasons.Length) loop
            Ada.Text_IO.Put_Line ("    - " & DAL_Assess.Failed_Reasons (F));
         end loop;
      end if;

      --  HLR traceability per package
      declare
         Has_HLR : Boolean := False;
      begin
         for P in 1 .. Integer (Packages.Length) loop
            if not Packages (P).HLR_Tags.Is_Empty then
               if not Has_HLR then
                  Ada.Text_IO.New_Line;
                  Ada.Text_IO.Put_Line ("  HLR traceability:");
                  Has_HLR := True;
               end if;
               Ada.Text_IO.Put
                 ("    "
                  & Packages (P).File_Path (1 .. Packages (P).Path_Len)
                  & ": ");
               for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
                  if T > 1 then
                     Ada.Text_IO.Put (", ");
                  end if;
                  Put_Color ("33", Enable => Use_Color);
                  Ada.Text_IO.Put
                    (Packages (P).HLR_Tags (T).Tag
                       (1 .. Packages (P).HLR_Tags (T).Len));
                  Reset_Color (Enable => Use_Color);
               end loop;
               Ada.Text_IO.New_Line;
            end if;
         end loop;
      end;

      Ada.Text_IO.New_Line;
   end Render_Summary;

end Adacovex.Renderers.ANSI;
