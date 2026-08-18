with Ada.Text_IO;

package body Adacovex.Parsers is

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (2 .. S'Last);
   end Img;

   procedure Read_Line
     (F         : in out Ada.Text_IO.File_Type;
      File_Path : String;
      Line_Num  : Natural;
      Line      : out String;
      Last      : out Natural;
      Overflow  : out Boolean)
   is
      use Ada.Text_IO;
      Drain : String (1 .. Line'Length);
      DLast : Natural;
      Loc   : constant String :=
        File_Path & (if Line_Num > 0 then ":" & Img (Line_Num) else "");
   begin
      Get_Line (F, Line, Last);
      Overflow := False;
      if Last = Line'Last and then not End_Of_File (F) then
         if not End_Of_Line (F) then
            Overflow := True;
            loop
               exit when End_Of_File (F);
               Get_Line (F, Drain, DLast);
               exit when DLast < Line'Length;
            end loop;
         end if;
      end if;
      if Overflow then
         Put_Line
           (Standard_Error,
            "Error: "
            & Loc
            & ": line exceeds Max_Line buffer ("
            & Img (Line'Length)
            & " bytes)");
      end if;
   end Read_Line;

end Adacovex.Parsers;
