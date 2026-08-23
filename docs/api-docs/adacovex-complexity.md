# Adacovex.Complexity

Cyclomatic complexity checker for Ada source files. Scans a target directory for .ads/.adb files, computes per-file and per-subprogram cyclomatic complexity, and enforces configurable LOC and complexity gates. Native Ada implementation (zero external deps). HLR-COMPLEXITY: Cyclomatic complexity analysis

> **Note:** All items in this package are public.

## Types

### type Complexity_Result

```ada
type Complexity_Result is record
Files      : File_Vectors.Vector;
Total_LOC  : Natural := 0;
Violations : Violation_Vectors.Vector;
end record;
```

### type File_Metrics

```ada
type File_Metrics is record
Path       : String (1 .. 4096);
Path_Len   : Natural := 0;
LOC        : Natural := 0;
Complexity : Natural := 0;
Subs       : Subprogram_Vectors.Vector;
end record;
```

### type Subprogram_Info

```ada
type Subprogram_Info is record
Name       : String (1 .. 128);
Name_Len   : Natural := 0;
Line       : Natural := 0;
Complexity : Natural := 0;
LOC        : Natural := 0;
end record;
```

### type Violation

```ada
type Violation is record
File_Path : String (1 .. 4096);
File_Len  : Natural := 0;
Message   : String (1 .. Max_Message);
Msg_Len   : Natural := 0;
end record;
```

## Functions

### function Analyze_Project (Target_Dir : Standard.String) return Adacovex.Complexity.Complexity_Result

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` |  |

### function Check_Gates (Result : Adacovex.Complexity.Complexity_Result; Max_File_LOC : Standard.Natural; Max_File_Pct : Standard.Natural; Max_Fn_Complexity : Standard.Natural; Max_File_Complexity : Standard.Natural) return Adacovex.Complexity.Violation_Vectors.Vector

| Parameter | Description |
|-----------|-------------|
| `Max_File_Complexity` |  |
| `Max_File_LOC` |  |
| `Max_File_Pct` |  |
| `Max_Fn_Complexity` |  |
| `Result` |  |

## Procedures

### procedure Print_Report (Result : Adacovex.Complexity.Complexity_Result; Check_Mode : Standard.Boolean; Violations : Adacovex.Complexity.Violation_Vectors.Vector; Max_File_LOC : Standard.Natural; Max_File_Pct : Standard.Natural; Max_Fn_Complexity : Standard.Natural; Max_File_Complexity : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `Check_Mode` |  |
| `Max_File_Complexity` |  |
| `Max_File_LOC` |  |
| `Max_File_Pct` |  |
| `Max_Fn_Complexity` |  |
| `Result` |  |
| `Violations` |  |
