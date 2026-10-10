with Ada.Strings.Fixed;
with Adacovex.Test_Support;
with Adacovex.Prove_Patch;

package body Adacovex_Prove_Patch_Tests is

   use Ada.Strings.Fixed;

   function Contains (S : String; Sub : String) return Boolean is
   begin
      return Index (S, Sub) > 0;
   end Contains;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Prove_Patch;

      Buf : String (1 .. 4096);
      BL  : Natural;

      procedure Merge_Check
        (Original : String;
         Patch    : String;
         Expected : String;
         Want_OK  : Boolean;
         Label    : String)
      is
         OK : Boolean;
      begin
         Apply (Original, Patch, Buf, BL, OK);
         R.Check (OK = Want_OK, Label & ": OK flag");
         if OK then
            R.Check (Buf (1 .. BL) = Expected, Label & ": merged text");
         end if;
      end Merge_Check;

      VT100_Orig : constant String :=
        "package VT100 is"
        & ASCII.LF
        & "   procedure Reset;"
        & ASCII.LF
        & "   procedure Move_Cursor"
        & ASCII.LF
        & "     (Line : in Natural; Column : in Natural);"
        & ASCII.LF
        & "end VT100;"
        & ASCII.LF;

      VT100_Patch : constant String :=
        "package VT100 with SPARK_Mode => On is"
        & ASCII.LF
        & "   procedure Reset with SPARK_Mode => On;"
        & ASCII.LF
        & "   procedure Move_Cursor (Line : in Natural; Column : in Natural)"
        & ASCII.LF
        & "     with SPARK_Mode => On;"
        & ASCII.LF
        & "end VT100;"
        & ASCII.LF;

      VT100_Expected : constant String :=
        "package VT100 with SPARK_Mode => On is"
        & ASCII.LF
        & "   procedure Reset with SPARK_Mode => On;"
        & ASCII.LF
        & "   procedure Move_Cursor (Line : in Natural; Column : in Natural)"
        & ASCII.LF
        & "     with SPARK_Mode => On;"
        & ASCII.LF
        & "end VT100;"
        & ASCII.LF;
   begin
      --  Has_Proof: docstring-only patches carry no proof aspects; a patch
      --  with SPARK_Mode / Pre / Post / Global aspects does.
      R.Check
        (not Has_Proof
               ("--  A docstring-only patch."
                & ASCII.LF
                & "package V is"
                & ASCII.LF
                & "end V;"),
         "docstring-only patch has no proof");
      R.Check
        (Has_Proof
           ("package V with SPARK_Mode => On is" & ASCII.LF & "end V;"),
         "SPARK_Mode aspect detected");
      R.Check
        (Has_Proof ("   procedure P with Post => True;" & ASCII.LF),
         "Post contract detected");
      R.Check
        (Has_Proof ("   procedure P with Pre => True;" & ASCII.LF),
         "Pre contract detected");
      R.Check
        (Has_Proof ("   function F with Global => null;" & ASCII.LF),
         "Global contract detected");

      --  Full merge: package-level aspect spliced, subprogram declarations
      --  (single- and multi-line) replaced by the patch's aspect-carrying
      --  declarations.
      Merge_Check
        (VT100_Orig,
         VT100_Patch,
         VT100_Expected,
         True,
         "package aspect + subprogram aspects");

      --  Package-level aspect only: subprograms stay original when the
      --  patch mirrors them without aspects (the docstring-patch case).
      Merge_Check
        (VT100_Orig,
         "package VT100 with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure Reset;"
         & ASCII.LF
         & "   procedure Move_Cursor (Line : in Natural; Column : in Natural);"
         & ASCII.LF
         & "end VT100;"
         & ASCII.LF,
         "package VT100 with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure Reset;"
         & ASCII.LF
         & "   procedure Move_Cursor"
         & ASCII.LF
         & "     (Line : in Natural; Column : in Natural);"
         & ASCII.LF
         & "end VT100;"
         & ASCII.LF,
         True,
         "package aspect only");

      --  Subprogram aspects only (no package aspect): only the patched
      --  subprogram is replaced, the package line is untouched.
      Merge_Check
        (VT100_Orig,
         "package VT100 is"
         & ASCII.LF
         & "   procedure Reset with Post => True;"
         & ASCII.LF
         & "end VT100;"
         & ASCII.LF,
         "package VT100 is"
         & ASCII.LF
         & "   procedure Reset with Post => True;"
         & ASCII.LF
         & "   procedure Move_Cursor"
         & ASCII.LF
         & "     (Line : in Natural; Column : in Natural);"
         & ASCII.LF
         & "end VT100;"
         & ASCII.LF,
         True,
         "subprogram aspect only");

      --  Name matching is exact: a patch entry for a subprogram the
      --  original does not declare fails loudly rather than silently
      --  dropping the contract.
      Merge_Check
        (VT100_Orig,
         "package VT100 is"
         & ASCII.LF
         & "   procedure No_Such_Proc with Post => True;"
         & ASCII.LF
         & "end VT100;"
         & ASCII.LF,
         "",
         False,
         "unmatched subprogram fails");

      --  Overloads: each patch entry takes the next matching original
      --  declaration, so only the first overload is patched when the patch
      --  names it once.
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer);"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Integer);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer) with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer) with Post => True;"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Integer);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "first overload patched");

      --  Overload matching is profile-aware: a patch entry for the
      --  two-argument overload replaces the two-argument original, never
      --  the same-named parameterless sibling (the vt100 dogfood case --
      --  Scroll_Screen appears both with and without arguments).
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P;"
         & ASCII.LF
         & "   procedure P (A : in Integer);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer) with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P;"
         & ASCII.LF
         & "   procedure P (A : in Integer) with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "second overload patched, parameterless sibling kept");

      --  Profile matching is whitespace-insensitive: the patch's
      --  single-line parameter list matches the original's multi-line
      --  parameter list.
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P"
         & ASCII.LF
         & "     (A : in Integer;"
         & ASCII.LF
         & "      B : in Integer);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Integer)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Integer)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "multi-line original profile matched");

      --  Default `in` modes are equivalent to bare modes: a patch that
      --  writes `in` matches an original that omits it (and vice versa).
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P (A : Integer; B : Boolean);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Boolean)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in Integer; B : in Boolean)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "default in mode matches bare mode");

      --  `in out` is a real mode: it must NOT be normalised away, and a
      --  patch declaring `in out` never matches a bare/`in` original.
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P (A : in out Integer; B : Boolean);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in out Integer; B : in Boolean)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in out Integer; B : in Boolean)"
         & ASCII.LF
         & "     with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "in out mode kept, matches itself");
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   procedure P (A : Integer);"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   procedure P (A : in out Integer) with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "",
         False,
         "in out does not match bare mode");

      --  A multi-line aspect clause (Post spanning lines with parentheses)
      --  is taken as part of the patch declaration block.
      Merge_Check
        ("package V is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer"
         & ASCII.LF
         & "     with Post => F'Result = X + 1;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer"
         & ASCII.LF
         & "     with Post => F'Result = X + 1;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "multi-line aspect clause");

      --  An original that already carries a package aspect is left alone
      --  (no double splicing).
      Merge_Check
        ("package V with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure P;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure P with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package V with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure P with Post => True;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "existing package aspect kept");

      --  A patch with no proof aspects at all merges to the original
      --  unchanged (the docstring-only case never builds an overlay).
      Merge_Check
        (VT100_Orig,
         VT100_Orig,
         VT100_Orig,
         True,
         "no-aspect patch merges unchanged");

      --  Body patches: a `package body` declaration line accepts the
      --  package-level aspect splice exactly like a spec.
      Merge_Check
        ("package body V is"
         & ASCII.LF
         & "   procedure P is"
         & ASCII.LF
         & "   begin"
         & ASCII.LF
         & "      null;"
         & ASCII.LF
         & "   end P;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package body V with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure P;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package body V with SPARK_Mode => On is"
         & ASCII.LF
         & "   procedure P is"
         & ASCII.LF
         & "   begin"
         & ASCII.LF
         & "      null;"
         & ASCII.LF
         & "   end P;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "body package-level aspect splice");

      --  Body subprogram declarations terminate at the `is` keyword: the
      --  patched declaration (with aspect) replaces the original
      --  declaration only, and the original body proper (begin/end) is
      --  preserved -- the stub body in the patch is never merged in.
      Merge_Check
        ("package body V is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer is"
         & ASCII.LF
         & "   begin"
         & ASCII.LF
         & "      return X + 1;"
         & ASCII.LF
         & "   end F;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package body V with SPARK_Mode => On is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer"
         & ASCII.LF
         & "     with SPARK_Mode => On is"
         & ASCII.LF
         & "   begin"
         & ASCII.LF
         & "      null;"
         & ASCII.LF
         & "   end F;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         "package body V with SPARK_Mode => On is"
         & ASCII.LF
         & "   function F (X : in Integer) return Integer"
         & ASCII.LF
         & "     with SPARK_Mode => On is"
         & ASCII.LF
         & "   begin"
         & ASCII.LF
         & "      return X + 1;"
         & ASCII.LF
         & "   end F;"
         & ASCII.LF
         & "end V;"
         & ASCII.LF,
         True,
         "body subprogram declaration replaced, body proper kept");

      --  The merged spec is the shape gnatprove analyses: package aspect on
      --  the declaration line, contract on the declaration.
      R.Check
        (Contains (VT100_Expected, "with SPARK_Mode => On"),
         "merged spec carries the package aspect");
      R.Check
        (Contains (VT100_Expected, "procedure Reset with SPARK_Mode => On"),
         "merged spec carries the subprogram aspect");
   end Run;

end Adacovex_Prove_Patch_Tests;
