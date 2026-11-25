# Adacovex.Cli_Help

The option text every help surface shares.

The console frame, the man page, and the tldr page describe one option
set. A description lives here, once, so a flag cannot read one way in
``--help`` and another way in the man page. The man page also files each
option under a task group, and the console frame prints its groups in the
same order, so a reader who knows one surface can find their way in the
other.

The table is closed by design: an option the table does not know gets an
empty description, and a test fails on that, so a new Known_Flags entry
cannot ship without its text.
HLR-CLI: One option table feeds the console frame, the man page, and the
tldr page.

> **Note:** All items in this package are public.

## Types

### type Option_Group

```ada
type Option_Group is
(Group_Assess,
Group_Report,
Group_Prove,
Group_Scope,
Group_CI,
Group_Diff,
Group_More);
```

> The task groups the help surfaces order their options by.

## Functions

### function Describe (Flag : Standard.String) return Standard.String

> The description of one option: its effect, its default, and the option it pairs with. Empty when the table does not know the option.

| Parameter | Description |
|-----------|-------------|
| `Flag` | Option name without its leading dashes. |

**Returns:** Description text, or "" for an unknown option.

### function Group_Of (Flag : Standard.String) return Adacovex.Cli_Help.Option_Group

> The group an option belongs to. An option the table does not place lands in Group_More, so it still appears on the page.

| Parameter | Description |
|-----------|-------------|
| `Flag` | Option name without its leading dashes. |

**Returns:** The group the man page files the option under.

### function Heading (G : Adacovex.Cli_Help.Option_Group) return Standard.String

> The heading of one group, with its trailing colon.

| Parameter | Description |
|-----------|-------------|
| `G` | Option group. |

**Returns:** Heading text, for example "Assess:".
