with Ada.Environment_Variables;

package body Adacovex.Ansi is

   Esc : constant Character := ASCII.ESC;

    --  Ada.Environment_Variables subprograms carry no Global contracts, so
    --  gnatprove 16 reports them with an assumed-global-null warning
    --  ("no Global contract available"); the pragma below silences exactly
    --  that warning for the env-var reads in this procedure, matching the
    --  pattern used by CPUs.Get_Temp_Directory.
    pragma Warnings (Off, "no Global contract available");

    procedure Init is
       TERM_Dumb : Boolean := False;
    begin
       if Ada.Environment_Variables.Exists ("TERM") then
          declare
             V : constant String := Ada.Environment_Variables.Value ("TERM");
          begin
             --  "dumb" terminals (and the empty value) take no colour.
             TERM_Dumb := V = "dumb" or else V = "";
          end;
       end if;
       Colour_Enabled :=
         not Ada.Environment_Variables.Exists ("NO_COLOR")
         and then not Ada.Environment_Variables.Exists ("CI")
         and then not TERM_Dumb;
    end Init;

    pragma Warnings (On, "no Global contract available");

   function Wrap (Code : String; S : String) return String is
   begin
      if not Colour_Enabled then
         return S;
      end if;
      return Esc & "[" & Code & "m" & S & Esc & "[0m";
   end Wrap;

   function Red (S : String) return String is (Wrap ("31", S));
   function Green (S : String) return String is (Wrap ("32", S));
   function Yellow (S : String) return String is (Wrap ("33", S));
   function Blue (S : String) return String is (Wrap ("34", S));
   function Dim (S : String) return String is (Wrap ("2", S));
   function Bold (S : String) return String is (Wrap ("1", S));

end Adacovex.Ansi;