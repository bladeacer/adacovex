package body Adacovex.IR_Synthesiser is
   pragma SPARK_Mode (On);

   --  Decimal digit string for a word size.
   --  @param W  The word size.
   --  @return "8", "16", "32", or "64".
   function Bits (W : Word_Size) return String
   with Global => null, Post => Bits'Result'Length in 1 .. 2
   is
   begin
      case W is
         when Bits_8  =>
            return "8";

         when Bits_16 =>
            return "16";

         when Bits_32 =>
            return "32";

         when Bits_64 =>
            return "64";
      end case;
   end Bits;

   function IR_Type_Name (Name : String; Cfg : Target_Config) return String is
   begin
      if Name = "int8_t" then
         return "IR_Int8";
      elsif Name = "int16_t" then
         return "IR_Int16";
      elsif Name = "int32_t" then
         return "IR_Int32";
      elsif Name = "int64_t" then
         return "IR_Int64";
      elsif Name = "uint8_t" then
         return "IR_UInt8";
      elsif Name = "uint16_t" then
         return "IR_UInt16";
      elsif Name = "uint32_t" then
         return "IR_UInt32";
      elsif Name = "uint64_t" then
         return "IR_UInt64";
      elsif Name = "size_t" or else Name = "usize" then
         pragma
           Assert (String'("IR_UInt" & Bits (Cfg.Target_Bits))'Length <= 9);
         return "IR_UInt" & Bits (Cfg.Target_Bits);
      elsif Name = "isize" then
         pragma
           Assert (String'("IR_Int" & Bits (Cfg.Target_Bits))'Length <= 9);
         return "IR_Int" & Bits (Cfg.Target_Bits);
      elsif Name = "ptrdiff_t" then
         pragma
           Assert (String'("IR_Int" & Bits (Cfg.Pointer_Bits))'Length <= 9);
         return "IR_Int" & Bits (Cfg.Pointer_Bits);
      elsif Name = "uintptr_t" then
         pragma
           Assert (String'("IR_UInt" & Bits (Cfg.Pointer_Bits))'Length <= 9);
         return "IR_UInt" & Bits (Cfg.Pointer_Bits);
      else
         return "";
      end if;
   end IR_Type_Name;

   function Lower_Type_Name (Name : String; Cfg : Target_Config) return String
   is
      IR : constant String := IR_Type_Name (Name, Cfg);
   begin
      if IR'Length = 0 then
         return "";
      end if;
      return "type " & Name & " is new Adacovex.Target_Profiles." & IR & ";";
   end Lower_Type_Name;

   function Synthesize_Package
     (Pkg_Name : String; Type_Names : String; Cfg : Target_Config)
      return String
   is
      Result : String (1 .. Max_Pkg_Len) := (others => ' ');
      RLen   : Natural range 0 .. Max_Pkg_Len := 0;

      --  Append a string to the synthesized text buffer.  The buffer is
      --  bounded, so appended text is truncated (never overflows) at the
      --  fixed-size limit.
      --  @param S  Text to append.
      procedure Append (S : String) is
      begin
         for I in S'Range loop
            if RLen < Result'Last then
               RLen := RLen + 1;
               Result (RLen) := S (I);
            end if;
            pragma Loop_Invariant (RLen <= Result'Last);
         end loop;
      end Append;
   begin
      Append ("--  Synthesized by Adacovex.IR_Synthesiser." & ASCII.LF);
      Append ("with Adacovex.Target_Profiles;" & ASCII.LF);
      Append (String'(1 => ASCII.LF));
      Append ("package " & Pkg_Name & " is" & ASCII.LF);

      declare
         I : Natural := Type_Names'First;
      begin
         while I <= Type_Names'Last loop
            pragma
              Loop_Invariant (I in Type_Names'First .. Type_Names'Last + 1);
            pragma Loop_Invariant (RLen <= Result'Last);
            pragma Loop_Variant (Increases => I);
            declare
               J    : Natural := I;
               Sub  : String (1 .. Type_Names'Length) := (others => ' ');
               SLen : Natural := 0;
            begin
               while J <= Type_Names'Last and then Type_Names (J) /= ',' loop
                  if Type_Names (J) /= ' ' then
                     SLen := SLen + 1;
                     Sub (SLen) := Type_Names (J);
                  end if;
                  J := J + 1;
                  pragma Loop_Invariant (SLen <= J - Type_Names'First);
                  pragma
                    Loop_Invariant
                      (J in Type_Names'First .. Type_Names'Last + 1);
                  pragma Loop_Invariant (J >= I);
                  pragma Loop_Variant (Increases => J);
               end loop;
               if SLen > 0 then
                  declare
                     Decl : constant String :=
                       Lower_Type_Name (Sub (1 .. SLen), Cfg);
                  begin
                     if Decl'Length > 0 then
                        Append ("   " & Decl & ASCII.LF);
                     end if;
                  end;
               end if;
               if J > Type_Names'Last then
                  I := Type_Names'Last + 1;
               else
                  I := J + 1;
               end if;
            end;
         end loop;
      end;

      Append ("end " & Pkg_Name & ";" & ASCII.LF);
      return Result (1 .. RLen);
   end Synthesize_Package;

end Adacovex.IR_Synthesiser;
