with Adacovex.Paths;

package body Adacovex_Paths_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Home : constant String := Adacovex.Paths.Home_Directory;
   begin
      --  Separator recognition: both DOS and Unix separators, and nothing
      --  else.
      R.Check (Adacovex.Paths.Is_Separator ('/'), "slash is a separator");
      R.Check
        (Adacovex.Paths.Is_Separator ('\'), "backslash is a separator");
      R.Check
        (not Adacovex.Paths.Is_Separator (':'),
         "colon is not a path separator");

      --  Absolute detection across POSIX roots, Windows roots, and the
      --  relative forms that must never be treated as absolute.
      R.Check (Adacovex.Paths.Is_Absolute ("/x"), "/x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("\x"), "\x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("C:\x"), "C:\x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("c:/x"), "c:/x is absolute");
      R.Check
        (not Adacovex.Paths.Is_Absolute ("x/y"), "x/y is relative");
      R.Check
        (not Adacovex.Paths.Is_Absolute (""), "the empty path is relative");
      R.Check (not Adacovex.Paths.Is_Absolute ("~"), "~ is relative");

      --  Join inserts exactly one '/' and trims the directory's trailing
      --  separators first.
      R.Check
        (Adacovex.Paths.Join ("/a", "b") = "/a/b", "join /a + b is /a/b");
      R.Check
        (Adacovex.Paths.Join ("/a/", "b") = "/a/b", "join trims one /");
      R.Check
        (Adacovex.Paths.Join ("", "b") = "b", "join of an empty dir is name");
      R.Check
        (Adacovex.Paths.Join ("/a", "") = "/a", "join of an empty name is dir");
      R.Check
        (Adacovex.Paths.Join ("C:\x", "y") = "C:\x/y",
         "join of a drive path adds a /");
      R.Check
        (Adacovex.Paths.Join ("/a//", "b") = "/a/b",
         "join trims every trailing separator");

      --  Trailing-separator stripping, including the lone-root case.
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/a/") = "/a",
         "strip removes one trailing slash");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/a//") = "/a",
         "strip removes every trailing slash");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/") = "/",
         "strip keeps a lone root");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("") = "",
         "strip keeps the empty path");

      --  Tilde expansion against the live home directory.
      R.Check
        (Adacovex.Paths.Expand_User ("~") = Home,
         "~ expands to the home directory");
      R.Check
        (Adacovex.Paths.Expand_User ("~/x") = Home & "/x",
         "~/x expands under the home directory");
      R.Check
        (Adacovex.Paths.Expand_User ("~other/x") = "~other/x",
         "~other is left untouched");
      R.Check
        (Adacovex.Paths.Expand_User ("/abs") = "/abs",
         "a non-tilde path is unchanged");
      R.Check
        (Adacovex.Paths.Expand_User ("~\x") = Home & "/x",
         "the Windows ~\x form expands too");
   end Run;

end Adacovex_Paths_Tests;
