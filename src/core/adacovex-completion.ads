--  Shell auto-completion script generator.
--  It writes a completion script for bash, fish, zsh, or PowerShell (pwsh).
--  The script completes the adacovex flag set.  The flag list comes from
--  Config.Flag_List.  This is the same Known_Flags list that the "did you
--  mean" suggestion walks.  The emitted scripts always match the binary's
--  live options.  The scripts are pure text with no runtime dependency and
--  no lookup.  Completion works offline and instantly.
--  HLR-CLI: shell completion generator

package Adacovex.Completion is

   --  Generate a completion script for the named shell.
   --  Shell names are case-insensitive.  Any name other than fish, zsh, or
   --  pwsh falls back to bash.  Flags is a space-separated list of CLI
   --  option names without leading dashes, for example Config.Flag_List.
   --  @param Shell  Target shell: bash, fish, zsh, or pwsh.
   --  @param Flags  Space-separated flag names to complete on.
   --  @return The complete script text (ready to feed a shell / save to a
   --    completion directory).
   function Generate (Shell : String; Flags : String) return String
   with Post => Generate'Result'Length > 0, Global => null;

end Adacovex.Completion;
