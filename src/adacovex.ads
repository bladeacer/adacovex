--  Root package for the adacovex verification tool suite.
--  Provides the version constant used throughout.
--  HLR-ARCH: Version constant
--  HLR-ARCH: Package hierarchy

with Adacovex_Version_Info;

package Adacovex is
   pragma SPARK_Mode (On);

   --  Version of this adacovex build.  Generated at build time from
   --  alire-dev.toml by tools/gen-version.py; release builds bundle the
   --  release tag via ADACOVEX_VERSION, so `--version` always reports the
   --  exact version the binary was built from.
   Version : constant String := Adacovex_Version_Info.Version;

end Adacovex;
