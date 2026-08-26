separate (Adacovex.Parsers.Manifest)
--  Whether to skip descending into a directory during a source walk:
--  VCS metadata, the adacovex config dir, installer/build outputs, and
--  Alire's own dependency cache never carry project source.
function Skip_Walk_Dir (N : String) return Boolean is
begin
   return
     N = ".git"
     or else N = ".hg"
     or else N = ".svn"
     or else N = ".adacovex"
     or else N = "alire"
     or else N = "obj"
     or else N = "bin";
end Skip_Walk_Dir;
