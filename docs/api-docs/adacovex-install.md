# Adacovex.Install

Installation method of the running adacovex binary.

Two consumers ask the question. ``adacovex status`` reports the method
and the binary path, so a user sees which installation the command on
PATH came from. The dependency-graph builder classifies a project's
reference to adacovex or its covex alias by it: a dev-scope component
when adacovex runs from a source checkout, a system-scope component
when it is installed outside any project.

The pure classification subprograms are SPARK_Mode On and are proved.
The three probes that read the command line, the environment, or the
filesystem keep the default-off body that Adacovex.Paths keeps for
the same job, and the package declares no explicit SPARK_Mode (Off).
HLR-MANIFEST: Installation method and dependency classification

> **Note:** All items in this package are public.

## Types

### type Install_Method

```ada
type Install_Method is (Source_Checkout, Alire_Global, On_Path);
```

## Functions

### function Classify (Path : Standard.String; Home : Standard.String; In_Checkout : Standard.Boolean) return Adacovex.Install.Install_Method

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory, "" when unknown. |
| `In_Checkout` | True when the path sits in an adacovex source |
| `Path` | Absolute path of the binary. |

**Returns:**  The home is bounded so its prefix concatenations stay well inside Natural, and its first index is bounded the same way: a slice keeps the origin it came from.

### function Dependency_Scope (M : Adacovex.Install.Install_Method) return Adacovex.Types.Component_Scope `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `M` | Installation method. |

**Returns:** Scope_Dev for Source_Checkout, Scope_System otherwise.

### function Detect return Adacovex.Install.Install_Method

**Returns:** Resolved method; On_Path when the path is unresolvable.

### function Is_Source_Checkout (Path : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Path` | Absolute path of the binary. |

**Returns:** True when an ancestor directory carries adacovex sources.

### function Self_Path return Standard.String

**Returns:** Absolute executable path, or "".

### function To_String (M : Adacovex.Install.Install_Method) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `M` | Installation method. |

**Returns:** "source-checkout", "alire-global", or "on-path".
