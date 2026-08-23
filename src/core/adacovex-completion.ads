--  Shell auto-completion script generator.
--  Emits a completion script for bash, fish, zsh, or PowerShell (pwsh)
--  that completes the adacovex flag set.  The flag list is passed in from
--  Config.Flag_List (the same Known_Flags list the "did you mean"
--  suggestion walks), so the emitted scripts always match the binary's
--  live options; the scripts themselves are pure text -- no runtime
--  dependency, no lookup -- so completion works offline and instantly.
--  HLR-CLI: shell completion generator

package Adacovex.Completion is

   --  Generate a completion script for the named shell.
   --  Shell names are case-insensitive; anything other than fish, zsh, or
   --  pwsh falls back to bash.  Flags is a space-separated list of CLI
   --  option names (without leading dashes), e.g. Config.Flag_List.
   --  @param Shell  Target shell: bash, fish, zsh, or pwsh.
   --  @param Flags  Space-separated flag names to complete on.
   --  @return The complete script text (ready to feed a shell / save to a
   --    completion directory).
   function Generate (Shell : String; Flags : String) return String
   with Post => Generate'Result'Length > 0, Global => null;

end Adacovex.Completion;
