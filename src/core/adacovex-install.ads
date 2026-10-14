with Adacovex.Types;

--  Installation method of the running adacovex binary.
--
--  Two consumers ask the question. `adacovex status` reports the method
--  and the binary path, so a user sees which installation the command on
--  PATH came from. The dependency-graph builder classifies a project's
--  reference to adacovex or its covex alias by it: a dev-scope component
--  when adacovex runs from a source checkout, a system-scope component
--  when it is installed outside any project.
--
--  The pure classification subprograms are SPARK_Mode On and are proved.
--  The three probes that read the command line, the environment, or the
--  filesystem keep the default-off body that Adacovex.Paths keeps for
--  the same job, and the package declares no explicit SPARK_Mode (Off).
--  HLR-MANIFEST: Installation method and dependency classification

package Adacovex.Install is

   --  How the binary was installed on this machine. Source_Checkout is a
   --  binary built inside an adacovex source tree. Alire_Global is a
   --  binary under a global Alire install prefix. On_Path is every other
   --  binary, for example an unpacked release on $PATH.
   type Install_Method is (Source_Checkout, Alire_Global, On_Path);

   --  Machine token of an installation method. It is the value
   --  `adacovex status` prints and writes to its JSON and metrics
   --  outputs, so the three outputs never drift.
   --  @param M  Installation method.
   --  @return "source-checkout", "alire-global", or "on-path".
   function To_String (M : Install_Method) return String
   with SPARK_Mode => On, Global => null;

   --  Classify an installation method from a binary path.
   --  A source checkout wins over every prefix rule, so a binary built
   --  inside a source tree is never reported as a global install. The
   --  remaining path is tested against the two documented Alire install
   --  prefixes: `~/.alire` (the `alr install` default) and
   --  `~/.local/bin`. Both separator characters are accepted, so the
   --  rule holds on Windows. A prefix must end at a path-component
   --  boundary: `/home/u/.alire-x/bin` is not under `~/.alire`.
   --  @param Path  Absolute path of the binary.
   --  @param Home  User home directory, "" when unknown.
   --  @param In_Checkout  True when the path sits in an adacovex source
   --    tree (see Is_Source_Checkout).
   --  @return The resolved installation method.
   function Classify
     (Path : String; Home : String; In_Checkout : Boolean)
      return Install_Method
   with
     SPARK_Mode => On,
     Global     => null,
     --  The home is bounded so its prefix concatenations stay well
     --  inside Natural, and its first index is bounded the same way:
     --  a slice keeps the origin it came from.
     Pre        =>
       Home'Length <= Types.Max_Path and Home'First <= Types.Max_Path;

   --  The dependency scope adacovex takes in a project's SBOM for this
   --  installation method. A source build is a development dependency
   --  of the project that references it. A binary installed outside a
   --  project is a system tool, like git or make.
   --  @param M  Installation method.
   --  @return Scope_Dev for Source_Checkout, Scope_System otherwise.
   function Dependency_Scope (M : Install_Method) return Types.Component_Scope
   with SPARK_Mode => On, Global => null;

   --  Whether the path sits inside an adacovex source tree. The walk
   --  starts at the directory that holds the binary and climbs at most
   --  12 parents. A directory is the checkout root when it carries
   --  src/adacovex.ads, the file only an adacovex source tree has.
   --  @param Path  Absolute path of the binary.
   --  @return True when an ancestor directory carries adacovex sources.
   function Is_Source_Checkout (Path : String) return Boolean;

   --  Absolute path of the running executable, or "" when it cannot be
   --  resolved. A relative command name is joined with the working
   --  directory first; when that file is absent, the PATH lookup
   --  answers.
   --  @return Absolute executable path, or "".
   function Self_Path return String;

   --  Installation method of the running executable. The running binary
   --  is the tool being asked about, so no PATH probe of a second
   --  binary answers this.
   --  @return Resolved method; On_Path when the path is unresolvable.
   function Detect return Install_Method;

end Adacovex.Install;
