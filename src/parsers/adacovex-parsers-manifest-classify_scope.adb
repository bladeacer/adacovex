separate (Adacovex.Parsers.Manifest)
--  Classify a dependency name into a Component_Scope from the collected
--  manifest sets.  A name declared under a [[test-depends-on]] section is
--  test (a test-only dependency, regardless of which manifest declared it).
--  A name in the publishing manifest is base.  A name declared only in the
--  dev manifest is dev.  Any other name is transitive.
function Classify_Scope (Name : String) return Types.Component_Scope is
begin
   for I in 1 .. Integer (Test_Names.Length) loop
      if Test_Names (I).Len = Name'Length
        and then Test_Names (I).Name (1 .. Name'Length) = Name
      then
         return Types.Scope_Test;
      end if;
   end loop;
   for I in 1 .. Integer (Base_Names.Length) loop
      if Base_Names (I).Len = Name'Length
        and then Base_Names (I).Name (1 .. Name'Length) = Name
      then
         return Types.Scope_Base;
      end if;
   end loop;
   for I in 1 .. Integer (Dev_Names.Length) loop
      if Dev_Names (I).Len = Name'Length
        and then Dev_Names (I).Name (1 .. Name'Length) = Name
      then
         return Types.Scope_Dev;
      end if;
   end loop;
   return Types.Scope_Transitive;
end Classify_Scope;
