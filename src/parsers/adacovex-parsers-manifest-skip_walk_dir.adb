separate (Adacovex.Parsers.Manifest)
--  Whether to skip descending into a directory during a source walk:
--  VCS metadata, the adacovex config dir, installer/build outputs, virtual
--  environments, and Alire's own dependency cache never carry project
--  source.  `.venv` holds an installed copy of the Python packages a
--  target's requirements*.txt declare (often thousands of files); the tree
--  walk must not enumerate it -- the requirements file is the source of
--  truth for the Python dependency graph (the complexity check excludes it
--  for the same reason since 1.40.0).
--
--  Deliberately NOT here: `node_modules` (a vendor root the generic
--  vendored discovery must descend into) and `_build` is likewise left to
--  the walkers that own the skip decision per site -- the tools scan, the
--  graph-key language probe, and the GPR collection carry their own
--  extended skip sets so build-product trees are never enumerated while
--  vendor roots stay discoverable.
function Skip_Walk_Dir (N : String) return Boolean is
begin
   return
     N = ".git"
     or else N = ".hg"
     or else N = ".svn"
     or else N = ".adacovex"
     or else N = ".venv"
     or else N = "alire"
     or else N = "obj"
     or else N = "bin";
end Skip_Walk_Dir;
