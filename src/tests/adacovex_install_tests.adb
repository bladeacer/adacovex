with Ada.Directories;
with Ada.Text_IO;
with Adacovex.Install;
with Adacovex.Paths;
with Adacovex.Types;

package body Adacovex_Install_Tests is

   use type Adacovex.Install.Install_Method;
   use type Adacovex.Types.Component_Scope;

   --  Write one file, creating its parent directory.
   --  @param Path  File to write.
   --  @param Content  File content.
   procedure Write_File (Path : String; Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Write_File;

   --  Run the installation-method checks.
   --  @param R  Test runner collecting the results.
   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Home : constant String := Adacovex.Paths.Home_Directory;
   begin
      --  The machine token of each method: the value `adacovex status`
      --  prints and writes to its JSON and metrics outputs.
      R.Check
        (Adacovex.Install.To_String (Adacovex.Install.Source_Checkout)
         = "source-checkout",
         "source checkout token");
      R.Check
        (Adacovex.Install.To_String (Adacovex.Install.Alire_Global)
         = "alire-global",
         "alire global token");
      R.Check
        (Adacovex.Install.To_String (Adacovex.Install.On_Path) = "on-path",
         "on-path token");

      --  The prefix rules: the two documented Alire install prefixes,
      --  with both separator characters, and a home that carries a
      --  trailing separator.
      R.Check
        (Adacovex.Install.Classify (Home & "/.alire/bin/covex", Home, False)
         = Adacovex.Install.Alire_Global,
         "the alr install default prefix is alire-global");
      R.Check
        (Adacovex.Install.Classify (Home & "/.local/bin/covex", Home, False)
         = Adacovex.Install.Alire_Global,
         "the documented local bin prefix is alire-global");
      R.Check
        (Adacovex.Install.Classify
           ("C:\Users\dev\.alire\bin\covex", "C:\Users\dev", False)
         = Adacovex.Install.Alire_Global,
         "the Windows separators keep the rule");
      R.Check
        (Adacovex.Install.Classify
           (Home & "/.alire/bin/covex", Home & "/", False)
         = Adacovex.Install.Alire_Global,
         "a home with a trailing separator still matches");
      R.Check
        (Adacovex.Install.Classify
           ("/home/dev/.alire-x/bin/covex", "/home/dev", False)
         = Adacovex.Install.On_Path,
         "a prefix must end at a path-component boundary");
      R.Check
        (Adacovex.Install.Classify ("/usr/local/bin/covex", "/home/dev", False)
         = Adacovex.Install.On_Path,
         "a binary outside the home is on-path");
      R.Check
        (Adacovex.Install.Classify ("", "/home/dev", False)
         = Adacovex.Install.On_Path,
         "an empty path is on-path");
      R.Check
        (Adacovex.Install.Classify ("/usr/local/bin/covex", "", False)
         = Adacovex.Install.On_Path,
         "an empty home never matches a prefix");
      R.Check
        (Adacovex.Install.Classify (Home & "/.alire/bin/covex", Home, True)
         = Adacovex.Install.Source_Checkout,
         "a source checkout wins over every prefix rule");

      --  The scope rule the dependency graph applies: a source build is
      --  a development dependency, an install outside a project is a
      --  system tool.
      R.Check
        (Adacovex.Install.Dependency_Scope (Adacovex.Install.Source_Checkout)
         = Adacovex.Types.Scope_Dev,
         "a source build is a dev-scope dependency");
      R.Check
        (Adacovex.Install.Dependency_Scope (Adacovex.Install.Alire_Global)
         = Adacovex.Types.Scope_System,
         "a global install is a system-scope dependency");
      R.Check
        (Adacovex.Install.Dependency_Scope (Adacovex.Install.On_Path)
         = Adacovex.Types.Scope_System,
         "a binary on PATH is a system-scope dependency");

      --  The filesystem walk: a checkout root carries src/adacovex.ads,
      --  and the walk finds it from a binary below it. A tree without
      --  the marker never reports a checkout.
      Write_File ("obj/install_checkout/bin/covex", "binary" & ASCII.LF);
      Write_File
        ("obj/install_checkout/src/adacovex.ads",
         "package Adacovex is end Adacovex;" & ASCII.LF);
      Write_File
        ("obj/install_checkout/deep/inner/covex", "binary" & ASCII.LF);
      Write_File ("obj/install_plain/bin/covex", "binary" & ASCII.LF);
      R.Check
        (Adacovex.Install.Is_Source_Checkout
           ("obj/install_checkout/bin/covex"),
         "the checkout root is found from the binary directory");
      R.Check
        (Adacovex.Install.Is_Source_Checkout
           ("obj/install_checkout/deep/inner/covex"),
         "the walk climbs to a checkout root several parents up");
      R.Check
        (not Adacovex.Install.Is_Source_Checkout
               ("obj/install_plain/bin/covex"),
         "a tree without the adacovex sources is no checkout");
      R.Check
        (not Adacovex.Install.Is_Source_Checkout ("covex"),
         "a bare name climbs nowhere");
      R.Check
        (not Adacovex.Install.Is_Source_Checkout (""),
         "an empty path is no checkout");

      --  The live probes: the resolved path exists, and Detect is the
      --  classifier fed with that path, the home, and the walk.
      declare
         P : constant String := Adacovex.Install.Self_Path;
      begin
         if P'Length = 0 then
            R.Check
              (Adacovex.Install.Detect = Adacovex.Install.On_Path,
               "an unresolvable self path reports on-path");
         else
            R.Check (Ada.Directories.Exists (P), "the self path exists");
            R.Check
              (Adacovex.Install.Detect
               = Adacovex.Install.Classify
                   (P, Home, Adacovex.Install.Is_Source_Checkout (P)),
               "Detect wires the path, the home, and the walk");
            R.Check
              (Home'Length <= Adacovex.Types.Max_Path,
               "the home fits the classifier bound");
         end if;
      end;
   end Run;

end Adacovex_Install_Tests;
