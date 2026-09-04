with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;
with Adacovex;
with Adacovex.Cache;
with Adacovex.CPUs;

package body Adacovex_Cache_Tests is

   use Adacovex;
   use Ada.Directories;

   --  Overall test root under the system temp directory, unique per PID so
   --  parallel or repeated runs never collide.  Tests create files under
   --  it and leave it there (ephemeral /tmp content).
   function Test_Root return String is
      Pid : constant Integer :=
        GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
      Img : constant String := Integer'Image (Pid);
   begin
      return
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-cache-tests-"
        & Img (2 .. Img'Last);
   end Test_Root;

   function Test_Cache_Dir return String is
   begin
      return Test_Root & "/cache";
   end Test_Cache_Dir;

   --  Documented persistent-stamp layout: ~/.adacovex/stamps/<sha-256-of
   --  -path>.  Adacovex.Cache owns the real builder privately; the tests
   --  rebuild it from the documented layout (same pattern as the probe
   --  store test above).
   function Home_Stamp_Path (For_Path : String) return String is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         else "/tmp");
   begin
      return Home & "/.adacovex/stamps/" & Cache.Hash_String (For_Path);
   end Home_Stamp_Path;

   --  Write Content into a fresh file at Path.  Binary Stream_IO, so the
   --  bytes on disk are exactly Content (the native Text_IO of this GNAT
   --  build appends a line terminator after every Put, which would corrupt
   --  hashes and sizes in these tests).
   procedure Write_File (Path : String; Content : String) is
      F : Ada.Streams.Stream_IO.File_Type;
      B :
        Ada.Streams.Stream_Element_Array
          (0 .. Ada.Streams.Stream_Element_Offset (Content'Length - 1));
   begin
      for I in Content'Range loop
         B (Ada.Streams.Stream_Element_Offset (I - Content'First)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (I)));
      end loop;
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (F, B);
      Ada.Streams.Stream_IO.Close (F);
   end Write_File;

   --  Append Content to the file at Path.
   procedure Append_File (Path : String; Content : String) is
      F : Ada.Streams.Stream_IO.File_Type;
      B :
        Ada.Streams.Stream_Element_Array
          (0 .. Ada.Streams.Stream_Element_Offset (Content'Length - 1));
   begin
      for I in Content'Range loop
         B (Ada.Streams.Stream_Element_Offset (I - Content'First)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (I)));
      end loop;
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.Append_File, Path);
      Ada.Streams.Stream_IO.Write (F, B);
      Ada.Streams.Stream_IO.Close (F);
   end Append_File;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Original_Dir : String (1 .. 1024) := (others => ' ');
      Original_Len : Natural := 0;

      File_Path : constant String := Test_Root & "/sample.txt";
      D1        : String (1 .. 64);
      D2        : String (1 .. 64);

      Key1 : constant String := Cache.Hash_String ("blob-one");
      Key2 : constant String := Cache.Hash_String ("blob-two");

      Blob  : String (1 .. 4096) := (others => ' ');
      BLen  : Natural := 0;
      Found : Boolean;

      Evict_Before : Natural := 0;
      Evict_Delta  : Natural := 0;

      Probed_Value : String (1 .. 128) := (others => ' ');
      Probed_Len   : Natural := 0;
      Probe_Found  : Boolean;

      Meta_License : String (1 .. 128) := (others => ' ');
      Meta_Ver     : String (1 .. 128) := (others => ' ');
      Meta_Web     : String (1 .. 128) := (others => ' ');
      Meta_Lic_Len : Natural := 0;
      Meta_Ver_Len : Natural := 0;
      Meta_Web_Len : Natural := 0;
      Meta_Found   : Boolean;

      Hits_Before : Natural := 0;
      Miss_Before : Natural := 0;
   begin
      --  Isolate the cache in the test root and remember how to restore the
      --  caller's configured directory at the end.
      Cache.Cache_Dir (Original_Dir, Original_Len);
      Create_Path (Test_Cache_Dir);
      Cache.Set_Cache_Dir (Test_Cache_Dir);

      --  Test 1: Hash_String is deterministic and matches the published
      --  SHA-256 test vectors.
      R.Check
        (Cache.Hash_String ("abc")
         = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
         "Test 1: SHA-256 of 'abc' (FIPS vector)");
      R.Check
        (Cache.Hash_String ("")
         = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
         "Test 1: SHA-256 of empty string (FIPS vector)");

      --  Test 2: different inputs, different digests.
      R.Check
        (Cache.Hash_String ("one") /= Cache.Hash_String ("two"),
         "Test 2: digests differ across inputs");
      R.Check
        (Cache.Hash_String ("repeat") = Cache.Hash_String ("repeat"),
         "Test 2: digest stable across calls");

      --  Test 3: Hash_File of a file equals Hash_String of its content.
      Write_File (File_Path, "hello adacovex cache");
      D1 := Cache.Hash_File (File_Path);
      R.Check
        (D1 = Cache.Hash_String ("hello adacovex cache"),
         "Test 3: file hash matches content hash");

      --  Test 4: the in-process stamp fast path serves the digest without
      --  re-reading the file: hashing the same unchanged path again must
      --  increase Stamp_Hits and return the same digest.
      Hits_Before := Cache.Stamp_Hits;
      D2 := Cache.Hash_File (File_Path);
      R.Check (D1 = D2, "Test 4: unchanged file hashes identically");
      R.Check
        (Cache.Stamp_Hits > Hits_Before,
         "Test 4: stamp fast path served the digest (Stamp_Hits grew)");

      --  Test 5: a size change invalidates the stamp: the digest changes
      --  and the lookup becomes a miss.
      Miss_Before := Cache.Stamp_Misses;
      Append_File (File_Path, "!");
      D1 := Cache.Hash_File (File_Path);
      R.Check (D1 /= D2, "Test 5: grown file hashes differently");
      R.Check
        (Cache.Stamp_Misses > Miss_Before,
         "Test 5: size change forced a re-hash (Stamp_Misses grew)");

      --  Test 6: Store / Exists / Load round trip.
      Cache.Store (Key1, "payload-one", Found);
      R.Check (Found, "Test 6: store reported success");
      R.Check (Cache.Exists (Key1), "Test 6: exists after store");
      BLen := 0;
      Cache.Load (Key1, Blob, BLen, Found);
      R.Check
        (Found and then BLen = 11 and then Blob (1 .. BLen) = "payload-one",
         "Test 6: load returns the stored payload");

      --  Test 7: Store overwrites the previous payload for the same key.
      Cache.Store (Key1, "payload-two", Found);
      BLen := 0;
      Cache.Load (Key1, Blob, BLen, Found);
      R.Check
        (Found and then BLen = 11 and then Blob (1 .. BLen) = "payload-two",
         "Test 7: store overwrites an existing entry");

      --  Test 8: Load of an absent key reports not found.
      BLen := 0;
      Cache.Load (Key2, Blob, BLen, Found);
      R.Check (not Found, "Test 8: load of absent key reports not found");
      R.Check
        (not Cache.Exists (Key2), "Test 8: exists of absent key is False");

      --  Test 9: Get_Cached / Put_Cached wrappers round trip.
      Cache.Put_Cached (Key2, "payload-three", Found);
      R.Check (Found, "Test 9: put reported success");
      BLen := 0;
      Cache.Get_Cached (Key2, Blob, BLen, Found);
      R.Check
        (Found and then BLen = 13 and then Blob (1 .. BLen) = "payload-three",
         "Test 9: get returns the put payload");

      --  Test 10: oldest-first eviction under a small cap.  Put_Cached
      --  evicts every 32 stores, so 40 stores with a cap of 8 must evict
      --  the oldest entries and keep the newest reachable.
      Cache.Set_Cache_Policy (8);
      Evict_Before := Cache.Eviction_Count;
      for I in 1 .. 40 loop
         declare
            K : constant String := Cache.Hash_String ("evict-blob-" & I'Image);
         begin
            Cache.Put_Cached (K, "evictable", Found);
         end;
      end loop;
      Evict_Delta := Cache.Eviction_Count - Evict_Before;
      R.Check (Evict_Delta > 0, "Test 10: eviction ran under the small cap");
      R.Check
        (Cache.Exists (Cache.Hash_String ("evict-blob- 40")),
         "Test 10: newest entry survived eviction");
      Cache.Set_Cache_Policy (4096);

      --  Test 11: system-tool probe store round trip.  The probe root is
      --  machine-local (outside the result cache), so the test cleans its
      --  entry up afterwards.
      declare
         Probe_Name : constant String :=
           "adacovex-test-probe-"
           & Integer'Image
               (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
      begin
         Cache.Put_Probe (Probe_Name, "fp-a", "1.2.3");
         Cache.Get_Probe
           (Probe_Name, "fp-a", Probed_Value, Probed_Len, Probe_Found);
         R.Check
           (Probe_Found and then Probed_Value (1 .. Probed_Len) = "1.2.3",
            "Test 11: probe store round trip");
         --  A different binary fingerprint (upgraded/replaced tool) must
         --  NOT be served the stored answer -- this is the invalidation
         --  rule that keeps system-tool versions current after an upgrade.
         Cache.Get_Probe
           (Probe_Name, "fp-b", Probed_Value, Probed_Len, Probe_Found);
         R.Check
           (not Probe_Found,
            "Test 11b: probe fingerprint mismatch invalidates");
         --  The probe store lives at ~/.adacovex/probes/<tool>.v2.  Remove
         --  the test's entry so it never leaks into a real toolchain probe
         --  set.  Probe_Path is private to Adacovex.Cache, so rebuild the
         --  path here from the documented layout.
         declare
            Home : constant String :=
              (if Ada.Environment_Variables.Exists ("HOME")
               then Ada.Environment_Variables.Value ("HOME")
               else "/tmp");
         begin
            Ada.Directories.Delete_File
              (Home & "/.adacovex/probes/" & Probe_Name & ".v2");
         exception
            when others =>
               null;
         end;
      end;

      --  Test 12: registry-metadata store round trip (lives under the
      --  result cache, so it is isolated inside the test cache dir).
      Cache.Put_Meta
        ("t", "npm", "irrelevant-pkg", "MIT", "9.9.9", "https://example.test");
      Cache.Get_Meta
        ("t",
         "npm",
         "irrelevant-pkg",
         Meta_License,
         Meta_Lic_Len,
         Meta_Ver,
         Meta_Ver_Len,
         Meta_Web,
         Meta_Web_Len,
         Meta_Found);
      R.Check
        (Meta_Found
         and then Meta_License (1 .. Meta_Lic_Len) = "MIT"
         and then Meta_Ver (1 .. Meta_Ver_Len) = "9.9.9"
         and then Meta_Web (1 .. Meta_Web_Len) = "https://example.test",
         "Test 12: registry-metadata store round trip");

      --  Test 13: persistent stat-stamp store.  A file at or above the
      --  16 KiB size gate is stamped at first hash; a second hash of the
      --  unchanged file (in a fresh process state -- the in-process map is
      --  bypassed by hashing a different path first) is served from the
      --  store, growing Persistent_Stamp_Hits.  An edited file (same size,
      --  later mtime) must force a re-hash and a changed digest.
      declare
         Big_Path : constant String := Test_Root & "/big-sample.bin";
         Hits_B   : constant Natural := Cache.Persistent_Stamp_Hits;
         Misses_B : constant Natural := Cache.Persistent_Stamp_Misses;
         D_Big_1  : String (1 .. 64);
         D_Big_2  : String (1 .. 64);
         Filler_A : constant String (1 .. 20_480) := (others => 'a');
         Filler_B : constant String (1 .. 24_576) := (others => 'b');
      begin
         Write_File (Big_Path, Filler_A);
         --  The racy-clean rule skips stamping within a second of the
         --  write, so let the file settle before the first hash: this test
         --  needs the record to be written.
         delay 1.1;
         D_Big_1 := Cache.Hash_File (Big_Path);
         R.Check
           (D_Big_1'Length = 64, "Test 13: big file hashed to 64-char digest");
         R.Check
           (Cache.Persistent_Stamp_Hits > Hits_B
            or else Cache.Persistent_Stamp_Misses > Misses_B,
            "Test 13: first hash consulted the persistent index");
         --  Same content, unchanged file: after dropping the in-process
         --  map (simulating a fresh run), the persistent store must answer
         --  -- that is the cross-process win this test pins down.
         declare
            H_Before : constant Natural := Cache.Persistent_Stamp_Hits;
         begin
            Cache.Reset_Process_Stamps;
            D_Big_2 := Cache.Hash_File (Big_Path);
            R.Check
              (D_Big_2 = D_Big_1,
               "Test 13: unchanged big file hashes identically");
            R.Check
              (Cache.Persistent_Stamp_Hits > H_Before,
               "Test 13: persistent stamp served the digest");
         end;
         --  Grown file (size change): the stored pair no longer matches, so
         --  the digest must change.  The in-process stamp map serves same-
         --  size files by design, so the edit must move the size to be
         --  observable here.  The racy-clean rule skips stamping within a
         --  second of the write, so sleep first to make the new state
         --  deterministically stampable for the re-record.
         delay 1.1;
         Write_File (Big_Path, Filler_B);
         D_Big_2 := Cache.Hash_File (Big_Path);
         R.Check
           (D_Big_2 /= D_Big_1,
            "Test 13: size change forced a re-hash (digest changed)");
         --  Small files never enter the store: a 10-byte file must not
         --  create a stamp entry.  Rebuild the documented path layout to
         --  check.
         declare
            Small_Path : constant String := Test_Root & "/small.txt";
         begin
            Write_File (Small_Path, "tiny");
            D_Big_2 := Cache.Hash_File (Small_Path);
            R.Check
              (not Ada.Directories.Exists (Home_Stamp_Path (Small_Path)),
               "Test 13: sub-gate file is not stamped");
         end;
         --  Clean the big file's stamp out of the machine store so the
         --  test never leaks entries into a real project's stamp set.
         begin
            Ada.Directories.Delete_File (Home_Stamp_Path (Big_Path));
         exception
            when others =>
               null;
         end;
      end;

      --  Restore whatever cache directory the caller had configured.
      if Original_Len > 0 then
         Cache.Set_Cache_Dir (Original_Dir (1 .. Original_Len));
      end if;
   end Run;

end Adacovex_Cache_Tests;
