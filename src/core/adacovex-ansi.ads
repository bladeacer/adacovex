--  Shared ANSI colour helper for adacovex stdout.
--
--  adacovex colours its terminal output to make the important lines stand
--  out.  Colour is disabled automatically when the output would not take it:
--  inside CI (`CI`), under `NO_COLOR`, or with `TERM=dumb`.  This keeps CI
--  logs plain and machine-readable.  adacovex is NO_COLOR-clean and never
--  emits escape codes when the environment opts out.
--  HLR-ANSI: Terminal colour support

package Adacovex.Ansi is

   --  Whether ANSI colour is enabled for this run.  Set by Init.  When False
   --  every colour helper returns the input unchanged.
   Colour_Enabled : Boolean := False;

   --  Resolve colour support once from the environment: enabled unless
   --  NO_COLOR is set, a CI variable is set, or TERM is "dumb".  Idempotent.
   procedure Init;

   --  Wrap S in the requested ANSI SGR sequence when colour is enabled,
   --  returning S unchanged otherwise.
   function Red (S : String) return String;
   function Green (S : String) return String;
   function Yellow (S : String) return String;
   function Blue (S : String) return String;
   function Dim (S : String) return String;
   function Bold (S : String) return String;

end Adacovex.Ansi;