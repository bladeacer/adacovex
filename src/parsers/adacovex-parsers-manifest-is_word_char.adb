separate (Adacovex.Parsers.Manifest)
--  Whether C bounds a tool-name word in a line. A word is a maximal run
--  of lowercase letters, digits, underscore, and hyphen ([a-z0-9_-]).
--  Uppercase letters do not start or continue a word, so "Makefile" and
--  "MAKE" never match the lowercase tool "make".
--  @param C  Character to classify.
--  @return True when the character can appear in a tool-name word.
function Is_Word_Char (C : Character) return Boolean is
begin
   return
     (C in 'a' .. 'z')
     or else (C in '0' .. '9')
     or else C = '_'
     or else C = '-';
end Is_Word_Char;
