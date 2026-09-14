with Adacovex.CPUs;
with Ada.Directories;
with Ada.Environment_Variables;

package body Adacovex_CPUs_Tests is

   --  The temp directory the documented TMPDIR / TEMP / TMP chain selects.
   --  @return Expected temp directory image.
   function Expected_Temp_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("TMPDIR") then
         return Ada.Environment_Variables.Value ("TMPDIR");
      elsif Ada.Environment_Variables.Exists ("TEMP") then
         return Ada.Environment_Variables.Value ("TEMP");
      elsif Ada.Environment_Variables.Exists ("TMP") then
         return Ada.Environment_Variables.Value ("TMP");
      else
         return "/tmp";
      end if;
   end Expected_Temp_Dir;

   --  True when any documented CI marker variable is present.  The marker
   --  list mirrors the package contract, so a marker that stops being
   --  honoured fails this test.
   --  @return Expected Is_Running_In_CI verdict for this environment.
   function Expected_In_CI return Boolean is
      use Ada.Environment_Variables;
   begin
      return
        Exists ("CI")
        or else Exists ("GITHUB_ACTIONS")
        or else Exists ("GITLAB_CI")
        or else Exists ("TF_BUILD")
        or else Exists ("BUILDKITE")
        or else Exists ("CIRCLECI")
        or else Exists ("TRAVIS")
        or else Exists ("APPVEYOR")
        or else Exists ("JENKINS_URL");
   end Expected_In_CI;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Cores : constant Natural := Adacovex.CPUs.Detect_Core_Count;
   begin
      --  Host detection.
      R.Check (Cores >= 1, "the detected core count is at least one");
      R.Check
        (Adacovex.CPUs.Get_Shell_Command = "sh",
         "the spawned-command shell is sh");
      R.Check
        (Adacovex.CPUs.Get_Temp_Directory = Expected_Temp_Dir,
         "the temp directory follows the TMPDIR/TEMP/TMP chain");
      R.Check
        (Ada.Directories.Exists (Adacovex.CPUs.Get_Temp_Directory),
         "the resolved temp directory exists");
      R.Check
        (Adacovex.CPUs.Is_Running_In_CI = Expected_In_CI,
         "the CI verdict follows the documented marker variables");

      --  The auto default leaves two cores free outside CI.
      R.Check
        (Adacovex.CPUs.Default_Prove_Jobs (8, True) = 8,
         "in CI the auto default uses every core");
      R.Check
        (Adacovex.CPUs.Default_Prove_Jobs (8, False) = 6,
         "outside CI the auto default reserves two cores");
      R.Check
        (Adacovex.CPUs.Default_Prove_Jobs (3, False) = 1,
         "the auto default never drops below one job");
      R.Check
        (Adacovex.CPUs.Default_Prove_Jobs (2, False) = 1,
         "a two-core host still gets one job");
      R.Check
        (Adacovex.CPUs.Default_Prove_Jobs (0, False) = 1,
         "an unknown core count still gets one job");

      --  The --jobs resolution: -1 auto, 0 all cores, positive explicit.
      R.Check
        (Adacovex.CPUs.Resolve_Jobs (5, False) = 5,
         "an explicit --jobs value is used as given");
      R.Check
        (Adacovex.CPUs.Resolve_Jobs (0, False) = Cores,
         "-j0 resolves to the detected core count");
      R.Check
        (Adacovex.CPUs.Resolve_Jobs (-1, True) = Cores,
         "the auto default in CI resolves to the detected core count");
      R.Check
        (Adacovex.CPUs.Resolve_Jobs (-1, False) = Natural'Max (1, Cores - 2),
         "the auto default outside CI reserves two cores");

      --  The serve worker pool stays within 2 .. 8 and tracks the host.
      R.Check
        (Adacovex.CPUs.Default_Serve_Workers (0) = 2,
         "an unknown core count starts the serve pool at two");
      R.Check
        (Adacovex.CPUs.Default_Serve_Workers (2) = 2,
         "a two-core host uses a two-worker pool");
      R.Check
        (Adacovex.CPUs.Default_Serve_Workers (5) = 5,
         "a mid-range host sizes the pool to its cores");
      R.Check
        (Adacovex.CPUs.Default_Serve_Workers (8) = 8,
         "an eight-core host uses an eight-worker pool");
      R.Check
        (Adacovex.CPUs.Default_Serve_Workers (64) = 8,
         "a large host caps the serve pool at eight");

      --  The verbose justification matches the resolved job count.
      R.Check
        (Adacovex.CPUs.Jobs_Justification (4, 8, False) = "explicit --jobs= 4",
         "an explicit job count is justified as explicit");
      R.Check
        (Adacovex.CPUs.Jobs_Justification (0, 8, False)
         = "auto default (all cores): -j0",
         "-j0 is justified as all cores");
      R.Check
        (Adacovex.CPUs.Jobs_Justification (-1, 8, True)
         = "auto default (CI): using all 8 cores",
         "the CI auto default is justified with the core count");
      R.Check
        (Adacovex.CPUs.Jobs_Justification (-1, 8, False)
         = "auto default: 8 - 2 = 6 jobs (reserved 2 cores for system)",
         "the auto default states the reserved cores");
      R.Check
        (Adacovex.CPUs.Jobs_Justification (-1, 1, False)
         = "auto default: 1 - 2 = 1 jobs (reserved 2 cores for system)",
         "the auto default floors the job count at one");
   end Run;

end Adacovex_CPUs_Tests;
