separate (Adacovex.Parsers.Manifest)
--  Whether a directory base name denotes a vendored-code directory that
--  adacovex treats as a scope=vendored dependency source.
--  @param N  Directory base name.
--  @return True for vendored directory names.
function Is_Vendor_Dir_Name (N : String) return Boolean is
begin
   return
     N = "vendor"
     or else N = "vendored"
     or else N = "third_party"
     or else N = "third-party"
     or else N = "extern"
     or else N = "external"
     or else N = "deps"
     or else N = "submodules"
     or else N = ".vendor"
     or else N = "lib"
     or else N = "contrib"
     or else N = "node_modules";
end Is_Vendor_Dir_Name;
