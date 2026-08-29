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

   --  Decide whether colour is allowed for a run from the environment
   --  signals.  Colour is allowed unless a CI variable is set, NO_COLOR is
   --  set, or TERM is "dumb" (or empty).  This is the pure, testable core of
   --  Init; it never touches the environment itself.
   --  @param CI_Set  True when a CI variable is present in the environment.
   --  @param No_Color_Set  True when NO_COLOR is present in the environment.
   --  @param Term_Dumb  True when TERM is "dumb" (or set to an empty value).
   --  @return True when colour is allowed for this run.
   function Colour_Allowed
     (CI_Set : Boolean; No_Color_Set : Boolean; Term_Dumb : Boolean)
      return Boolean;

   --  Resolve colour support once from the environment: enabled unless
   --  NO_COLOR is set, a CI variable is set, or TERM is "dumb".  Idempotent.
   procedure Init;

   --  Wrap S in the requested ANSI SGR sequence when colour is enabled,
   --  returning S unchanged otherwise.
   --  @param S  Text to colour.
   --  @return S wrapped in the red SGR sequence, or S unchanged.
   function Red (S : String) return String;

   --  Wrap S in the green SGR sequence when colour is enabled.
   --  @param S  Text to colour.
   --  @return S wrapped in the green SGR sequence, or S unchanged.
   function Green (S : String) return String;

   --  Wrap S in the yellow SGR sequence when colour is enabled.
   --  @param S  Text to colour.
   --  @return S wrapped in the yellow SGR sequence, or S unchanged.
   function Yellow (S : String) return String;

   --  Wrap S in the blue SGR sequence when colour is enabled.
   --  @param S  Text to colour.
   --  @return S wrapped in the blue SGR sequence, or S unchanged.
   function Blue (S : String) return String;

   --  Dim S when colour is enabled.
   --  @param S  Text to dim.
   --  @return S wrapped in the dim SGR sequence, or S unchanged.
   function Dim (S : String) return String;

   --  Bold S when colour is enabled.
   --  @param S  Text to embolden.
   --  @return S wrapped in the bold SGR sequence, or S unchanged.
   function Bold (S : String) return String;

end Adacovex.Ansi;
