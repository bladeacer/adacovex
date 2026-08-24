# Adacovex.Completion

Shell auto-completion script generator.
It writes a completion script for bash, fish, zsh, or PowerShell (pwsh).
The script completes the adacovex flag set.  The flag list comes from
Config.Flag_List.  This is the same Known_Flags list that the "did you
mean" suggestion walks.  The emitted scripts always match the binary's
live options.  The scripts are pure text with no runtime dependency and
no lookup.  Completion works offline and instantly.
HLR-CLI: shell completion generator

> **Note:** All items in this package are public.

## Functions

### function Generate (Shell : Standard.String; Flags : Standard.String) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Flags` | Space-separated flag names to complete on. |
| `Shell` | Target shell: bash, fish, zsh, or pwsh. |

**Returns:** The complete script text (ready to feed a shell / save to a
