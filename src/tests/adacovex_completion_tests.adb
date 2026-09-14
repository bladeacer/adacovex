with Adacovex.Completion;
with Adacovex.Config;

package body Adacovex_Completion_Tests is

   --  True when Needle appears in Haystack.
   --  @param Haystack  Text to search.
   --  @param Needle  Substring to look for.
   --  @return True when the substring is present.
   function Contains (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Needle'Length > Haystack'Length then
         return False;
      end if;
      for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   --  True when every space-separated token of Flags appears in Script.
   --  @param Script  Generated completion script.
   --  @param Flags  Space-separated flag names.
   --  @return True when every flag is completed on.
   function All_Flags_Present (Script : String; Flags : String) return Boolean
   is
      Pos : Natural := Flags'First;
   begin
      while Pos <= Flags'Last loop
         declare
            Fin : Natural := Pos;
         begin
            while Fin <= Flags'Last and then Flags (Fin) /= ' ' loop
               Fin := Fin + 1;
            end loop;
            if Fin > Pos and then not Contains (Script, Flags (Pos .. Fin - 1))
            then
               return False;
            end if;
            Pos := Fin + 1;
         end;
      end loop;
      return True;
   end All_Flags_Present;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Flags : constant String := Adacovex.Config.Flag_List;
      Plain : constant String := "target serve";
      B     : constant String := Adacovex.Completion.Generate ("bash", Plain);
      F     : constant String := Adacovex.Completion.Generate ("fish", Plain);
      Z     : constant String := Adacovex.Completion.Generate ("zsh", Plain);
      P     : constant String := Adacovex.Completion.Generate ("pwsh", Plain);
   begin
      --  Every supported shell produces its own script, and the scripts
      --  differ from each other.
      R.Check (B'Length > 0, "the bash script is not empty");
      R.Check (F'Length > 0, "the fish script is not empty");
      R.Check (Z'Length > 0, "the zsh script is not empty");
      R.Check (P'Length > 0, "the pwsh script is not empty");
      R.Check
        (B /= F
         and then B /= Z
         and then B /= P
         and then F /= Z
         and then F /= P
         and then Z /= P,
         "each shell gets a distinct script");

      --  Each script carries its own shell's entry point and the supplied
      --  flags.
      R.Check
        (Contains (B, "bash completion for adacovex")
         and then Contains (B, "compgen -W"),
         "the bash script installs a bash completion function");
      R.Check
        (Contains (F, "complete -c adacovex -l target")
         and then Contains (F, "complete -c covex -l serve"),
         "the fish script completes both command names");
      R.Check
        (Contains (Z, "#compdef adacovex covex")
         and then Contains (Z, "compdef _adacovex adacovex covex"),
         "the zsh script registers a compdef for both names");
      R.Check
        (Contains (P, "Register-ArgumentCompleter")
         and then Contains (P, "adacovex,covex"),
         "the pwsh script registers a native argument completer");
      R.Check (All_Flags_Present (B, Plain), "bash completes the given flags");
      R.Check (All_Flags_Present (F, Plain), "fish completes the given flags");
      R.Check (All_Flags_Present (Z, Plain), "zsh completes the given flags");
      R.Check (All_Flags_Present (P, Plain), "pwsh completes the given flags");

      --  Shell names are case-insensitive.
      R.Check
        (Adacovex.Completion.Generate ("FISH", Plain) = F
         and then Adacovex.Completion.Generate ("FiSh", Plain) = F,
         "the fish shell name is case-insensitive");
      R.Check
        (Adacovex.Completion.Generate ("Zsh", Plain) = Z,
         "the zsh shell name is case-insensitive");
      R.Check
        (Adacovex.Completion.Generate ("PWSH", Plain) = P,
         "the pwsh shell name is case-insensitive");
      R.Check
        (Adacovex.Completion.Generate ("BASH", Plain) = B,
         "the bash shell name is case-insensitive");

      --  Any unrecognised shell name falls back to bash.
      R.Check
        (Adacovex.Completion.Generate ("tcsh", Plain) = B,
         "an unknown shell falls back to the bash script");
      R.Check
        (Adacovex.Completion.Generate ("", Plain) = B,
         "an empty shell name falls back to the bash script");

      --  The real flag list reaches every script, so the emitted scripts
      --  always match the binary's live options.
      R.Check (Flags'Length > 0, "the live flag list is not empty");
      R.Check
        (All_Flags_Present
           (Adacovex.Completion.Generate ("bash", Flags), Flags),
         "the bash script completes the live flag list");
      R.Check
        (All_Flags_Present
           (Adacovex.Completion.Generate ("fish", Flags), Flags),
         "the fish script completes the live flag list");
      R.Check
        (All_Flags_Present
           (Adacovex.Completion.Generate ("zsh", Flags), Flags),
         "the zsh script completes the live flag list");
      R.Check
        (All_Flags_Present
           (Adacovex.Completion.Generate ("pwsh", Flags), Flags),
         "the pwsh script completes the live flag list");
   end Run;

end Adacovex_Completion_Tests;
