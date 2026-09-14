# STE100 Technical Names: Ada language constructs

The **Ada Language Constructs** category of the [STE100 Technical Names]
(ste100-technical-names.md) dictionary.  These terms name Ada language
features that generic English words cannot replace without losing technical
precision.

## Technical Name: Package
- **Part of Speech:** Noun
- **Definition:** A named collection of related declarations in Ada. A
  package has a visible specification and a private body.
- **Approved Form:** Package (singular), Packages (plural)
- **Do Not Use:** Module, Library unit, Component
- **Correct Example:** *A **package** groups the related subprograms.*
- **Incorrect Example:** *A module groups the related subprograms.*

## Technical Name: Package Body
- **Part of Speech:** Noun
- **Definition:** The implementation part of a package. It contains the
  bodies of the subprograms that the package specification declares.
- **Approved Form:** Package Body (singular), Package Bodies (plural)
- **Do Not Use:** Implementation file, Source file (when ambiguous)
- **Correct Example:** *The **package body** implements the declared subprograms.*
- **Incorrect Example:** *The implementation file implements the declared subprograms.*

## Technical Name: Specification
- **Part of Speech:** Noun
- **Definition:** The visible declaration part of a package or subprogram.
  In Ada, the specification is the `.ads` file of a package.
- **Approved Form:** Specification (singular), Specifications (plural)
- **Do Not Use:** Header, Interface file, Definition
- **Correct Example:** *The package **specification** declares the public subprograms.*
- **Incorrect Example:** *The package header declares the public subprograms.*

## Technical Name: Subprogram
- **Part of Speech:** Noun
- **Definition:** A named unit of executable code in Ada. A subprogram is
  either a procedure or a function.
- **Approved Form:** Subprogram (singular), Subprograms (plural)
- **Do Not Use:** Routine, Method, Function (for the general concept)
- **Correct Example:** *Every **subprogram** in the source tree has a docstring.*
- **Incorrect Example:** *Every routine in the source tree has a docstring.*

## Technical Name: Procedure
- **Part of Speech:** Noun
- **Definition:** A subprogram that performs an action and does not return a
  value.
- **Approved Form:** Procedure (singular), Procedures (plural)
- **Do Not Use:** Routine, Operation
- **Correct Example:** *The **procedure** writes the report to a file.*
- **Incorrect Example:** *The routine writes the report to a file.*

## Technical Name: Function
- **Part of Speech:** Noun
- **Definition:** A subprogram that returns a value.
- **Approved Form:** Function (singular), Functions (plural)
- **Do Not Use:** Method, Callable
- **Correct Example:** *The **function** returns the number of cores.*
- **Incorrect Example:** *The method returns the number of cores.*

## Technical Name: Task
- **Part of Speech:** Noun
- **Definition:** A unit of concurrent execution in the Ada language.
- **Approved Form:** Task (singular), Tasks (plural)
- **Do Not Use:** Thread, Process, Job, Execution Unit
- **Correct Example:** *The HTTP server runs a pool of four **tasks**.*
- **Incorrect Example:** *The HTTP server runs a pool of four threads.*

## Technical Name: Pragma
- **Part of Speech:** Noun
- **Definition:** A compiler directive in the Ada programming language.
- **Approved Form:** Pragma (singular), Pragmas (plural)
- **Do Not Use:** Compiler directive, Annotation, Attribute
- **Correct Example:** *The **pragma** `SPARK_Mode` enables SPARK analysis.*
- **Incorrect Example:** *The compiler directive `SPARK_Mode` enables SPARK analysis.*

## Technical Name: Aspect
- **Part of Speech:** Noun
- **Definition:** A declaration-level property in Ada 2012 that attaches
  contracts to a declaration. Examples are `Pre`, `Post`, and `Global`.
- **Approved Form:** Aspect (singular), Aspects (plural)
- **Do Not Use:** Property, Annotation, Attribute
- **Correct Example:** *The **aspect** `Pre` states the precondition.*
- **Incorrect Example:** *The property `Pre` states the precondition.*

## Technical Name: Contract
- **Part of Speech:** Noun
- **Definition:** The set of preconditions, postconditions, and global
  dependencies that describe subprogram behaviour for the proof tool.
- **Approved Form:** Contract (singular), Contracts (plural)
- **Do Not Use:** Agreement, Promise, Guarantee
- **Correct Example:** *gnatprove proves the **contracts** of every subprogram.*
- **Incorrect Example:** *gnatprove proves the guarantees of every subprogram.*

## Technical Name: Generic
- **Part of Speech:** Modifier
- **Definition:** A unit that is parameterised and that a caller instantiates
  with actual parameters. Used with the nouns package, subprogram, or
  procedure.
- **Approved Form:** Generic (as modifier only)
- **Do Not Use:** Template, Parameterised unit (as a noun)
- **Correct Example:** *A **generic** package instantiates a vector type.*
- **Incorrect Example:** *A template package instantiates a vector type.*

## Technical Name: Type
- **Part of Speech:** Noun
- **Definition:** A named set of values and the operations on those values in
  Ada.
- **Approved Form:** Type (singular), Types (plural)
- **Do Not Use:** Datatype, Data type (when the Ada type is meant)
- **Correct Example:** *The **type** `IR_Int32` is a bounded integer type.*
- **Incorrect Example:** *The datatype `IR_Int32` is a bounded integer type.*

## Technical Name: Object
- **Part of Speech:** Noun
- **Definition:** A variable or constant that has a type in Ada.
- **Approved Form:** Object (singular), Objects (plural)
- **Do Not Use:** Instance (when the Ada object is meant), Variable (when a
  constant is also possible)
- **Correct Example:** *The proof checks that every **object** is initialised.*
- **Incorrect Example:** *The proof checks that every instance is initialised.*

## Technical Name: SPARK
- **Part of Speech:** Noun
- **Definition:** The formally analysable subset of Ada that the gnatprove
  proof tool verifies. adacovex targets the Platinum SPARK level.
- **Approved Form:** SPARK (exact capitals)
- **Do Not Use:** Spark, spark, Ada subset (when SPARK is meant)
- **Correct Example:** *The source is written in **SPARK** and proved with gnatprove.*
- **Incorrect Example:** *The source is written in Spark and proved with gnatprove.*
