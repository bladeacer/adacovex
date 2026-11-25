--  The option text every help surface shares.
--
--  The console frame, the man page, and the tldr page describe one option
--  set. A description lives here, once, so a flag cannot read one way in
--  `--help` and another way in the man page. The man page also files each
--  option under a task group, and the console frame prints its groups in the
--  same order, so a reader who knows one surface can find their way in the
--  other.
--
--  The table is closed by design: an option the table does not know gets an
--  empty description, and a test fails on that, so a new Known_Flags entry
--  cannot ship without its text.
--  HLR-CLI: One option table feeds the console frame, the man page, and the
--  tldr page.

package Adacovex.Cli_Help is

   --  The task groups the help surfaces order their options by.
   type Option_Group is
     (Group_Assess,
      Group_Report,
      Group_Prove,
      Group_Scope,
      Group_CI,
      Group_Diff,
      Group_More);

   --  Every group, in display order. The console frame and the man page read
   --  this order, so the two surfaces never disagree about what comes first.
   All_Groups : constant array (Positive range <>) of Option_Group :=
     (Group_Assess,
      Group_Report,
      Group_Prove,
      Group_Scope,
      Group_CI,
      Group_Diff,
      Group_More);

   --  The heading of one group, with its trailing colon.
   --  @param G  Option group.
   --  @return Heading text, for example "Assess:".
   function Heading (G : Option_Group) return String;

   --  The group an option belongs to. An option the table does not place
   --  lands in Group_More, so it still appears on the page.
   --  @param Flag  Option name without its leading dashes.
   --  @return The group the man page files the option under.
   function Group_Of (Flag : String) return Option_Group;

   --  The description of one option: its effect, its default, and the option
   --  it pairs with. Empty when the table does not know the option.
   --  @param Flag  Option name without its leading dashes.
   --  @return Description text, or "" for an unknown option.
   function Describe (Flag : String) return String;

end Adacovex.Cli_Help;
