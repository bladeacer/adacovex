with Ada.Directories;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.CPUs;

package body Adacovex.VCS is

   use GNAT.OS_Lib;
   use type Shell_Family;

   Max_Capture : constant := 4096;

   --  Spawn the host shell with its command-line flag, redirecting
   --  stdout+stderr to Out_File. The shell is used so CWD-dependent tools
   --  (fossil open, svn export) can be driven with a change-directory
   --  prefix without changing the process directory. It is `sh -c` on
   --  POSIX hosts and `cmd /c` on native Windows.
   procedure Run_Cmd
     (Cmd      : String;
      Out_File : String;
      Success  : out Boolean;
      Code     : out Integer)
   is
      Prog : String_Access :=
        Locate_Exec_On_Path (Adacovex.CPUs.Get_Shell_Command);
   begin
      if Prog = null then
         Success := False;
         Code := 127;
         return;
      end if;
      Spawn
        (Prog.all,
         (new String'(Adacovex.CPUs.Get_Shell_Option), new String'(Cmd)),
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
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-vcs-capture-"
        & Pid_Img (2 .. Pid_Img'Last)
        & ".out";
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

   function Host_Shell return Shell_Family is
   begin
      if GNAT.OS_Lib.Directory_Separator = '\' then
         return CMD_Shell;
      end if;
      return POSIX_Shell;
   end Host_Shell;

   function Quote_Path (S : Shell_Family; Path : String) return String is
   begin
      case S is
         when POSIX_Shell =>
            return ''' & Path & ''';

         when CMD_Shell   =>
            return '"' & Path & '"';
      end case;
   end Quote_Path;

   function Change_Dir_Prefix (S : Shell_Family; Dir : String) return String is
   begin
      case S is
         when POSIX_Shell =>
            return "cd " & Quote_Path (S, Dir) & " && ";

         when CMD_Shell   =>
            --  /d makes cmd.exe follow a drive change as well.
            return "cd /d " & Quote_Path (S, Dir) & " && ";
      end case;
   end Change_Dir_Prefix;

   function Null_Device (S : Shell_Family) return String is
   begin
      case S is
         when POSIX_Shell =>
            return "/dev/null";

         when CMD_Shell   =>
            return "NUL";
      end case;
   end Null_Device;

   --  The host's own shell, pre-selected at each call site, so a command
   --  line reads as one string built from one shell's rules.
   function Q (Path : String) return String is
   begin
      return Quote_Path (Host_Shell, Path);
   end Q;

   function In_Dir (Dir : String) return String is
   begin
      return Change_Dir_Prefix (Host_Shell, Dir);
   end In_Dir;

   function ND return String is
   begin
      return Null_Device (Host_Shell);
   end ND;

   --  Copy Src to Dst in Ada. The VCS command lines used to shell out to
   --  `cp`; a file copy needs no shell on any platform, and GNAT.OS_Lib
   --  already provides it.
   procedure Copy_Path (Src : String; Dst : String; Ok : out Boolean) is
   begin
      GNAT.OS_Lib.Copy_File (Src, Dst, Ok);
   end Copy_Path;

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
   --  keyword is absent. The value runs to the end of the line.
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
        ("git -C " & Q (D) & " rev-parse --is-inside-work-tree", ND, S, C);
      if S and then C = 0 then
         return Git;
      end if;
      Run_Cmd ("jj -R " & Q (D) & " root", ND, S, C);
      if S and then C = 0 then
         return Jujutsu;
      end if;
      Run_Cmd ("hg -R " & Q (D) & " root", ND, S, C);
      if S and then C = 0 then
         return Mercurial;
      end if;
      Run_Cmd ("svn info " & Q (D), ND, S, C);
      if S and then C = 0 then
         return Subversion;
      end if;
      Run_Cmd (In_Dir (D) & "fossil status", ND, S, C);
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
      return
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-diff-"
        & Pid_Img (2 .. Pid_Img'Last);
   end Snapshot_Path;

   procedure Remove_Dir (Tmp_Path : String) is
      S : Boolean;
      C : Integer;
   begin
      --  Each shell removes a directory its own way; neither form needs a
      --  POSIX layer on Windows.
      if Host_Shell = CMD_Shell then
         Run_Cmd ("rmdir /s /q " & Q (Tmp_Path), ND, S, C);
      else
         Run_Cmd ("rm -rf " & Q (Tmp_Path), ND, S, C);
      end if;
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
        ("git --git-dir="
         & Q (Git_Dir)
         & " rev-parse --verify "
         & Q (Base_Ref & "^{commit}"),
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
      end if;

      --  jj templates changed syntax across versions: 0.44+ wants the bare
      --  keyword (`-T commit_id`), older jj wants the braced form
      --  (`-T '{commit_id}'`). Try the new form first, then the legacy one
      --  so both jj generations resolve change ids.
      Run_Capture
        ("jj -R "
         & Q (Target_Dir)
         & " log -r "
         & Q (Base_Ref)
         & " --no-graph -T commit_id",
         Buf,
         BLen,
         Code,
         OK);
      if OK and then Code = 0 and then BLen > 0 then
         return First_Line (Buf, BLen);
      end if;
      Run_Capture
        ("jj -R "
         & Q (Target_Dir)
         & " log -r "
         & Q (Base_Ref)
         & " --no-graph -T "
         & Q ("{commit_id}"),
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
              ("git -C "
               & Q (Target_Dir)
               & " worktree remove --force "
               & Q (Tmp),
               ND,
               S,
               C);
            Run_Cmd
              ("git -C "
               & Q (Target_Dir)
               & " worktree add --detach "
               & Q (Tmp)
               & " "
               & Q (Base_Ref),
               ND,
               S,
               C);
            Success := S and then C = 0;

         when Mercurial  =>
            Remove_Dir (Tmp);
            Run_Cmd
              ("hg -R "
               & Q (Target_Dir)
               & " archive -r "
               & Q (Base_Ref)
               & " "
               & Q (Tmp),
               ND,
               S,
               C);
            Success := S and then C = 0;

         when Subversion =>
            Remove_Dir (Tmp);
            --  Repository URL of the working copy (SVN >= 1.9 --show-item).
            Run_Capture
              ("svn info --show-item url " & Q (Target_Dir), Buf, BLen, C, OK);
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
               Run_Capture ("svn info " & Q (Target_Dir), Buf, BLen, C, OK);
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
              ("svn export -r "
               & Q (Base_Ref)
               & " "
               & Q (URL (1 .. ULen))
               & " "
               & Q (Tmp),
               ND,
               S,
               C);
            Success := S and then C = 0;

         when Fossil     =>
            Remove_Dir (Tmp);
            --  The `.fslckout` file in a checkout is only a checkout-local
            --  DB without the project history, so ask fossil for the real
            --  repository database path and copy that instead.
            Run_Capture
              (In_Dir (Target_Dir) & "fossil info", Buf, BLen, C, OK);
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
               --  The directory and the database copy are Ada work, not
               --  shell work: `mkdir -p` and `cp` are POSIX names, and both
               --  steps need no shell on any platform.
               Ada.Directories.Create_Path (Tmp);
               declare
                  Copied : Boolean := False;
               begin
                  Copy_Path (Fossil_DB, Tmp & "/repo.fossil", Copied);
                  if not Copied then
                     Success := False;
                     return;
                  end if;
               end;
               Run_Cmd
                 (In_Dir (Tmp)
                  & "fossil open "
                  & Q ("repo.fossil")
                  & " "
                  & Q (Base_Ref),
                  ND,
                  S,
                  C);
               Success := S and then C = 0;
            end;

         when Jujutsu    =>
            --  Export jj branches/refs into the internal git store, then
            --  snapshot via a git worktree (jj commits are git commits).
            Run_Cmd ("jj -R " & Q (Target_Dir) & " git export", ND, S, C);
            declare
               Commit : constant String :=
                 Resolve_JJ_Commit (Target_Dir, Base_Ref);
            begin
               if Commit'Length = 0 then
                  Success := False;
                  return;
               end if;
               Run_Cmd
                 ("git -C "
                  & Q (Target_Dir)
                  & " worktree remove --force "
                  & Q (Tmp),
                  ND,
                  S,
                  C);
               Run_Cmd
                 ("git --git-dir="
                  & Q (Target_Dir & "/.jj/repo/store/git")
                  & " worktree add --detach "
                  & Q (Tmp)
                  & " "
                  & Q (Commit),
                  ND,
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
              ("git -C "
               & Q (Target_Dir)
               & " worktree remove --force "
               & Q (Tmp_Path),
               ND,
               S,
               C);

         when Jujutsu =>
            Run_Cmd
              ("git --git-dir="
               & Q (Target_Dir & "/.jj/repo/store/git")
               & " worktree remove --force "
               & Q (Tmp_Path),
               ND,
               S,
               C);
            Remove_Dir (Tmp_Path);

         when others  =>
            Remove_Dir (Tmp_Path);
      end case;
   end Remove_Snapshot;

end Adacovex.VCS;
