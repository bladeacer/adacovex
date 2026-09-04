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
--  `_build` is the shared convention for Sphinx (docs/_build), Meson, Dune,
--  and GNAT collinear build outputs.  A build-product tree can never be a
--  vendored package (no ecosystem manifest is authored there), so every
--  consumer of this predicate can skip it safely -- measured on the
--  self-audit tree at ~750 stats per run for docs/_build alone (1.45.0).
--
--  Deliberately NOT here: `node_modules` (a vendor root the generic
--  vendored discovery must descend into) -- the walkers that own the skip
--  decision per site add their own extended entries so build-product trees
--  are never enumerated while vendor roots stay discoverable.
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
     or else N = "bin"
     or else N = "_build";
end Skip_Walk_Dir;
