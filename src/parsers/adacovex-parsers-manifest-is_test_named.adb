separate (Adacovex.Parsers.Manifest)
--  Whether a dependency name carries a test label.  The full name is
--  checked first, then the last path segment after any '/' or ':' (which
--  covers npm scope prefixes -- "@playwright/test" -- as well as Go
--  module paths such as "github.com/stretchr/testify", maven
--  groupId:artifactId names such as "org.testng:testng", and composer
--  vendor/package names).  A name (or its last segment) that starts or
--  ends with the literal word "test" is test-labelled (for example
--  @playwright/test, vitest, supertest, testify, testng).
--  @param Name  Dependency name (may be scoped, path-like, or
--    colon-separated, e.g. "@playwright/test").
--  @return True when the name (or its last segment) starts or ends with
--    "test".
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
   declare
      F : Natural := F0;
   begin
      for I in F0 .. L0 loop
         if Name (I) = '/' or else Name (I) = ':' then
            F := I + 1;
         end if;
      end loop;
      if F > F0 and then Pre_Or_Suffix (F, L0) then
         return True;
      end if;
   end;
   return False;
end Is_Test_Named;
