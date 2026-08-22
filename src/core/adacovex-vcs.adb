with Ada.Directories;
with Ada.Text_IO;
with GNAT.OS_Lib;

package body Adacovex.VCS is

   use GNAT.OS_Lib;

   Max_Capture : constant := 4096;

   --  Spawn `sh -c Cmd` (Linux/WSL), redirecting stdout+stderr to Out_File.
   --  sh is used so CWD-dependent tools (fossil open, svn) can be driven
   --  with a `cd ... &&` prefix without changing the process directory.
   procedure Run_Cmd
     (Cmd      : String;
      Out_File : String;
      Success  : out Boolean;
      Code     : out Integer)
   is
      Prog : String_Access := Locate_Exec_On_Path ("sh");
   begin
      if Prog = null then
         Success := False;
         Code := 127;
         return;
      end if;
      Spawn
        (Prog.all,
         (new String'("-c"), new String'(Cmd)),
         Out_File,
         Success,
         Code,
         Err_To_Out => True);
      Free (Prog);
   end Run_Cmd;

   --  Run Cmd and capture its output (first Max_Capture chars) into Buf.
   --  Also returns the exit code so callers can distinguish "tool missing"
   --  from "command failed" when needed.
   procedure Run_Capture
     (Cmd  : String;
      Buf  : out String;
      BLen : out Natural;
      Code : out Integer;
      OK   : out Boolean)
   is
      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        "/tmp/adacovex-vcs-capture-" & Pid_Img (2 .. Pid_Img'Last) & ".out";
      F       : Ada.Text_IO.File_Type;
   begin
      BLen := 0;
      Run_Cmd (Cmd, Tmp, OK, Code);
      if OK then
         begin
            Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
            while not Ada.Text_IO.End_Of_File (F) loop
               declare
                  Line : constant String := Ada.Text_IO.Get_Line (F);
               begin
                  for I in Line'Range loop
                     if BLen < Buf'Last then
                        BLen := BLen + 1;
                        Buf (BLen) := Line (I);
                     end if;
                  end loop;
                  if BLen < Buf'Last then
                     BLen := BLen + 1;
                     Buf (BLen) := ASCII.LF;
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (F);
         exception
            when others =>
               null;
         end;
         begin
            Ada.Directories.Delete_File (Tmp);
         exception
            when others =>
               null;
         end;
      end if;
   end Run_Capture;

   --  First non-empty line of the captured buffer, clamped to Max_Path.
   function First_Line (Buf : String; BLen : Natural) return String
   with
     SPARK_Mode => On,
     Pre        =>
       Buf'First >= 1 and Buf'Last < Natural'Last and BLen <= Buf'Length,
     Global     => null
   is
      Start : Natural := Buf'First;
      Stop  : Natural :=
        (if BLen = 0 then Buf'First else Buf'First + BLen - 1);
   begin
      if BLen = 0 then
         return "";
      end if;
      --  Stop is valid because BLen <= Buf'Length and Buf'Last < Natural'Last
      pragma Assert (Stop >= Buf'First and Stop <= Buf'Last);
      while Start <= Stop and then Buf (Start) = ASCII.LF loop
         pragma Loop_Invariant (Start >= Buf'First);
         pragma Loop_Invariant (Start <= Stop + 1);
         pragma Loop_Variant (Increases => Start);
         Start := Start + 1;
      end loop;
      if Start > Stop then
         return "";
      end if;
      declare
         E : Natural := Start;
      begin
         while E <= Stop and then Buf (E) /= ASCII.LF loop
            pragma Loop_Invariant (E >= Start);
            pragma Loop_Invariant (E <= Stop + 1);
            pragma Loop_Variant (Increases => E);
            E := E + 1;
         end loop;
         if E > Start then
            return Buf (Start .. E - 1);
         end if;
      end;
      return "";
   end First_Line;

   --  Value of the first "Keyword: value" line in the captured output
   --  (e.g. svn's "URL: ..." or fossil's "repository: ..."), or "" when the
   --  keyword is absent.  The value runs to the end of the line.
   function Field_Value
     (Buf : String; BLen : Natural; Keyword : String) return String
   with
     SPARK_Mode => On,
     Pre        =>
       Buf'First >= 1
       and Buf'Last < Natural'Last
       and Keyword'First >= 1
       and Keyword'Last < Natural'Last
       and BLen <= Buf'Length,
     Global     => null
   is
      Stop : Natural := (if BLen = 0 then Buf'First else Buf'First + BLen - 1);
      I    : Natural := Buf'First;
   begin
      if BLen = 0 then
         return "";
      end if;
      pragma Assert (Stop >= Buf'First and Stop <= Buf'Last);
      while I <= Stop loop
         pragma Loop_Invariant (I >= Buf'First);
         pragma Loop_Invariant (I <= Stop + 1);
         pragma Loop_Variant (Increases => I);
         if Keyword'Length > 0
           and then Stop - I + 1 >= Keyword'Length
           and then Buf (I .. I + Keyword'Length - 1) = Keyword
         then
            declare
               St : Natural := I + Keyword'Length;
               En : Natural := St;
            begin
               pragma Assert (St >= Buf'First and St <= Stop + 1);
               while En <= Stop and then Buf (En) = ' ' loop
                  pragma Loop_Invariant (En >= St);
                  pragma Loop_Invariant (En <= Stop + 1);
                  pragma Loop_Variant (Increases => En);
                  En := En + 1;
               end loop;
               St := En;
               while En <= Stop and then Buf (En) /= ASCII.LF loop
                  pragma Loop_Invariant (En >= St);
                  pragma Loop_Invariant (En <= Stop + 1);
                  pragma Loop_Variant (Increases => En);
                  En := En + 1;
               end loop;
               if En > St then
                  return Buf (St .. En - 1);
               end if;
            end;
         --  Keyword empty: treat as not found, skip.

         end if;
         I := I + 1;
      end loop;
      return "";
   end Field_Value;

   function Exists (P : String) return Boolean is
   begin
      return Ada.Directories.Exists (P);
   end Exists;

   function Detect (Target_Dir : String) return VCS_Kind is
      D : constant String := Target_Dir;
      S : Boolean;
      C : Integer;
   begin
      --  Marker files first: deterministic and subprocess-free.
      if Exists (D & "/.git") then
         return Git;
      elsif Exists (D & "/.jj") then
         return Jujutsu;
      elsif Exists (D & "/.hg") then
         return Mercurial;
      elsif Exists (D & "/.svn") then
         return Subversion;
      elsif Exists (D & "/.fslckout") or else Exists (D & "/_FOSSIL_") then
         return Fossil;
      end if;

      --  Command probes as a fallback (legacy checkouts without markers).
      Run_Cmd
        ("git -C '" & D & "' rev-parse --is-inside-work-tree",
         "/dev/null",
         S,
         C);
      if S and then C = 0 then
         return Git;
      end if;
      Run_Cmd ("jj -R '" & D & "' root", "/dev/null", S, C);
      if S and then C = 0 then
         return Jujutsu;
      end if;
      Run_Cmd ("hg -R '" & D & "' root", "/dev/null", S, C);
      if S and then C = 0 then
         return Mercurial;
      end if;
      Run_Cmd ("svn info '" & D & "'", "/dev/null", S, C);
      if S and then C = 0 then
         return Subversion;
      end if;
      Run_Cmd ("cd '" & D & "' && fossil status", "/dev/null", S, C);
      if S and then C = 0 then
         return Fossil;
      end if;
      return Unknown;
   end Detect;

   function Is_Managed (Target_Dir : String) return Boolean is
   begin
      return Detect (Target_Dir) /= Unknown;
   end Is_Managed;
   function To_String (Kind : VCS_Kind) return String with SPARK_Mode => On is
   begin
      case Kind is
         when Git        =>
            return "git";

         when Mercurial  =>
            return "mercurial";

         when Subversion =>
            return "subversion";

         when Fossil     =>
            return "fossil";

         when Jujutsu    =>
            return "jj";

         when Unknown    =>
            return "";
      end case;
   end To_String;

   function Tool_Name (Kind : VCS_Kind) return String with SPARK_Mode => On is
   begin
      case Kind is
         when Git        =>
            return "git";

         when Mercurial  =>
            return "hg";

         when Subversion =>
            return "svn";

         when Fossil     =>
            return "fossil";

         when Jujutsu    =>
            return "jj";

         when Unknown    =>
            return "";
      end case;
   end Tool_Name;

   function UX_Note (Kind : VCS_Kind) return String with SPARK_Mode => On is
   begin
      case Kind is
         when Subversion =>
            return
              "Note: Subversion support is limited (no local history, "
              & "network-dependent checkouts); consider converting this "
              & "repo to git for the best adacovex experience.";

         when Fossil     =>
            return
              "Note: Fossil support is workable but niche; consider "
              & "converting this repo to git for the best adacovex "
              & "experience.";

         when others     =>
            return "";
      end case;
   end UX_Note;

   --  Unique snapshot path under the system temp directory.
   function Snapshot_Path return String is
      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
   begin
      return "/tmp/adacovex-diff-" & Pid_Img (2 .. Pid_Img'Last);
   end Snapshot_Path;

   procedure Remove_Dir (Tmp_Path : String) is
      S : Boolean;
      C : Integer;
   begin
      Run_Cmd ("rm -rf '" & Tmp_Path & "'", "/dev/null", S, C);
   end Remove_Dir;

   --  Resolve Base_Ref to a git commit id for a jj repo: first try the
   --  internal git store directly (branches/tags/commit ids resolve after
   --  `jj git export`), then ask jj for the commit id of any change id.
   function Resolve_JJ_Commit
     (Target_Dir : String; Base_Ref : String) return String
   is
      Git_Dir : constant String := Target_Dir & "/.jj/repo/store/git";
      Buf     : String (1 .. Max_Capture) := (others => ' ');
      BLen    : Natural := 0;
      Code    : Integer;
      OK      : Boolean;
   begin
      Run_Capture
        ("git --git-dir='"
         & Git_Dir
         & "' rev-parse --verify '"
         & Base_Ref
         & "'^{commit}",
         Buf,
         BLen,
         Code,
         OK);
      if OK and then Code = 0 and then BLen > 0 then
         declare
            L : constant String := First_Line (Buf, BLen);
         begin
            if L'Length > 0 then
               return L;
            end if;
         end;
      end if;      --  jj templates changed syntax across versions: 0.44+ wants the bare
      --  keyword (`-T commit_id`), older jj wants the braced form
      --  (`-T '{commit_id}'`).  Try the new form first, then the legacy one
      --  so both jj generations resolve change ids.
      Run_Capture
        ("jj -R '"
         & Target_Dir
         & "' log -r '"
         & Base_Ref
         & "' --no-graph -T commit_id",
         Buf,
         BLen,
         Code,
         OK);
      if OK and then Code = 0 and then BLen > 0 then
         return First_Line (Buf, BLen);
      end if;
      Run_Capture
        ("jj -R '"
         & Target_Dir
         & "' log -r '"
         & Base_Ref
         & "' --no-graph -T '{commit_id}'",
         Buf,
         BLen,
         Code,
         OK);
      if OK and then Code = 0 and then BLen > 0 then
         return First_Line (Buf, BLen);
      end if;
      return "";
   end Resolve_JJ_Commit;

   procedure Make_Snapshot
     (Target_Dir : String;
      Kind       : VCS_Kind;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean)
   is
      Tmp  : constant String := Snapshot_Path;
      S    : Boolean;
      C    : Integer;
      Buf  : String (1 .. Max_Capture) := (others => ' ');
      BLen : Natural := 0;
      OK   : Boolean;
      URL  : String (1 .. Max_Capture) := (others => ' ');
      ULen : Natural := 0;
   begin
      Tmp_Len := Tmp'Length;
      for I in Tmp'Range loop
         Tmp_Path (I - Tmp'First + 1) := Tmp (I);
      end loop;
      Success := False;

      case Kind is
         when Git        =>
            --  Drop any stale worktree from a previous run, then create.
            Run_Cmd
              ("git -C '"
               & Target_Dir
               & "' worktree remove --force '"
               & Tmp
               & "'",
               "/dev/null",
               S,
               C);
            Run_Cmd
              ("git -C '"
               & Target_Dir
               & "' worktree add --detach '"
               & Tmp
               & "' '"
               & Base_Ref
               & "'",
               "/dev/null",
               S,
               C);
            Success := S and then C = 0;

         when Mercurial  =>
            Remove_Dir (Tmp);
            Run_Cmd
              ("hg -R '"
               & Target_Dir
               & "' archive -r '"
               & Base_Ref
               & "' '"
               & Tmp
               & "'",
               "/dev/null",
               S,
               C);
            Success := S and then C = 0;

         when Subversion =>
            Remove_Dir (Tmp);
            --  Repository URL of the working copy (SVN >= 1.9 --show-item).
            Run_Capture
              ("svn info --show-item url '" & Target_Dir & "'",
               Buf,
               BLen,
               C,
               OK);
            if OK and then C = 0 and then BLen > 0 then
               declare
                  L : constant String := First_Line (Buf, BLen);
               begin
                  if L'Length > 0 and then ULen = 0 then
                     ULen := L'Length;
                     for I in 1 .. L'Length loop
                        URL (I) := L (L'First + I - 1);
                     end loop;
                  end if;
               end;
            end if;
            --  Fallback for older svn: parse the "URL: ..." line.
            if ULen = 0 then
               Run_Capture ("svn info '" & Target_Dir & "'", Buf, BLen, C, OK);
               if OK and then C = 0 then
                  declare
                     V : constant String := Field_Value (Buf, BLen, "URL:");
                  begin
                     if V'Length > 0 and then V'Length <= URL'Last then
                        ULen := V'Length;
                        for I in 1 .. V'Length loop
                           URL (I) := V (V'First + I - 1);
                        end loop;
                     end if;
                  end;
               end if;
            end if;
            if ULen = 0 then
               Success := False;
               return;
            end if;
            Run_Cmd
              ("svn export -r '"
               & Base_Ref
               & "' '"
               & URL (1 .. ULen)
               & "' '"
               & Tmp
               & "'",
               "/dev/null",
               S,
               C);
            Success := S and then C = 0;

         when Fossil     =>
            Remove_Dir (Tmp);
            --  The `.fslckout` file in a checkout is only a checkout-local
            --  DB without the project history, so ask fossil for the real
            --  repository database path and copy that instead.
            Run_Capture
              ("cd '" & Target_Dir & "' && fossil info", Buf, BLen, C, OK);
            declare
               Fossil_DB : constant String :=
                 (if OK and then C = 0
                  then Field_Value (Buf, BLen, "repository:")
                  else "");
            begin
               if Fossil_DB'Length = 0 then
                  Success := False;
                  return;
               end if;
               Run_Cmd
                 ("mkdir -p '"
                  & Tmp
                  & "' && cp '"
                  & Fossil_DB
                  & "' '"
                  & Tmp
                  & "/repo.fossil' && cd '"
                  & Tmp
                  & "' && fossil open 'repo.fossil' '"
                  & Base_Ref
                  & "'",
                  "/dev/null",
                  S,
                  C);
               Success := S and then C = 0;
            end;

         when Jujutsu    =>
            --  Export jj branches/refs into the internal git store, then
            --  snapshot via a git worktree (jj commits are git commits).
            Run_Cmd
              ("jj -R '" & Target_Dir & "' git export", "/dev/null", S, C);
            declare
               Commit : constant String :=
                 Resolve_JJ_Commit (Target_Dir, Base_Ref);
            begin
               if Commit'Length = 0 then
                  Success := False;
                  return;
               end if;
               Run_Cmd
                 ("git -C '"
                  & Target_Dir
                  & "' worktree remove --force '"
                  & Tmp
                  & "'",
                  "/dev/null",
                  S,
                  C);
               Run_Cmd
                 ("git --git-dir='"
                  & Target_Dir
                  & "/.jj/repo/store/git' worktree add --detach '"
                  & Tmp
                  & "' '"
                  & Commit
                  & "'",
                  "/dev/null",
                  S,
                  C);
               Success := S and then C = 0;
            end;

         when Unknown    =>
            Success := False;
      end case;

      if not Success then
         Tmp_Len := 0;
         --  Best-effort cleanup of a partial snapshot so a failed run never
         --  leaks a stale directory under /tmp (git worktree registrations
         --  from a partial add are dropped by the next run's remove --force).
         Remove_Dir (Tmp);
      end if;
   end Make_Snapshot;

   procedure Remove_Snapshot
     (Target_Dir : String; Kind : VCS_Kind; Tmp_Path : String)
   is
      S : Boolean;
      C : Integer;
   begin
      case Kind is
         when Git     =>
            Run_Cmd
              ("git -C '"
               & Target_Dir
               & "' worktree remove --force '"
               & Tmp_Path
               & "'",
               "/dev/null",
               S,
               C);

         when Jujutsu =>
            Run_Cmd
              ("git --git-dir='"
               & Target_Dir
               & "/.jj/repo/store/git' worktree remove --force '"
               & Tmp_Path
               & "'",
               "/dev/null",
               S,
               C);
            Remove_Dir (Tmp_Path);

         when others  =>
            Remove_Dir (Tmp_Path);
      end case;
   end Remove_Snapshot;

end Adacovex.VCS;
