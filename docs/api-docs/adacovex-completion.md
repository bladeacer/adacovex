# Adacovex.Completion

Shell auto-completion script generator.
Emits a completion script for bash, fish, zsh, or PowerShell (pwsh)
that completes the adacovex flag set.  The flag list is passed in from
Config.Flag_List (the same Known_Flags list the "did you mean"
suggestion walks), so the emitted scripts always match the binary's
live options; the scripts themselves are pure text -- no runtime
dependency, no lookup -- so completion works offline and instantly.
HLR-CLI: shell completion generator

> **Note:** All items in this package are public.

## Functions

### function Generate (Shell : Standard.String; Flags : Standard.String) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Flags` | Space-separated flag names to complete on. |
| `Shell` | Target shell: bash, fish, zsh, or pwsh. |

**Returns:** The complete script text (ready to feed a shell / save to a
