with Adacovex.Types;
with Adacovex.Config;

package Adacovex.Server.HTTP is

   type Server_State is record
      Port        : Positive := 8080;
      Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural;
      Running     : Boolean := False;
   end record;

   procedure Start (State : Server_State);

end Adacovex.Server.HTTP;
