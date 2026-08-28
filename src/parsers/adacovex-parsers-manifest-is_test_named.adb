separate (Adacovex.Parsers.Manifest)
--  Whether an npm-style package name carries a test label.  The full
--  package name is checked first, then the unscoped name after any
--  leading "@scope/" prefix.  A name that starts or ends with the literal
--  word "test" is test-labelled (for example @playwright/test, vitest,
--  supertest).
--  @param Name  Package name (may be scoped, e.g. "@playwright/test").
--  @return True when the package name starts or ends with "test".
function Is_Test_Named (Name : String) return Boolean is
   F0 : constant Natural := Name'First;
   L0 : constant Natural := Name'Last;

   --  Whether the name slice Name (F .. L) starts or ends with "test".
   --  @param F  First index of the slice.
   --  @param L  Last index of the slice.
   --  @return True when the slice carries the word "test" at either end.
   function Pre_Or_Suffix (F : Natural; L : Natural) return Boolean is
   begin
      return
        L - F + 1 >= 4
        and then (Name (F .. F + 3) = "test"
                  or else Name (L - 3 .. L) = "test");
   end Pre_Or_Suffix;
begin
   if Pre_Or_Suffix (F0, L0) then
      return True;
   end if;
   if F0 <= L0 and then Name (F0) = '@' then
      declare
         F : Natural := F0;
      begin
         for I in F0 + 1 .. L0 loop
            if Name (I) = '/' then
               F := I + 1;
               exit;
            end if;
         end loop;
         if F <= L0 and then Pre_Or_Suffix (F, L0) then
            return True;
         end if;
      end;
   end if;
   return False;
end Is_Test_Named;
