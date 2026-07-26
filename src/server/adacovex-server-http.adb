with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Streams;
with GNAT.Sockets;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.HTML;

package body Adacovex.Server.HTTP is

   use GNAT.Sockets;
   use type Ada.Streams.Stream_Element_Offset;

   procedure Handle_Request
     (Channel  : Socket_Type;
      State    : Server_State);

   procedure Start (State : Server_State) is
      Sock   : Socket_Type;
      Addr   : Sock_Addr_Type;
      Family : Family_Type := Family_Inet;
   begin
      Ada.Text_IO.Put_Line ("Starting adacovex HTTP server on port" &
                            Positive'Image (State.Port) & "...");

      Create_Socket (Sock, Family, Socket_Stream);
      Set_Socket_Option (Sock, Socket_Level, (Reuse_Address, True));

      Addr.Addr := GNAT.Sockets.Addresses
        (Get_Host_By_Name ("127.0.0.1"), 1);
      Addr.Port := Port_Type (State.Port);
      Bind_Socket (Sock, Addr);
      Listen_Socket (Sock);

      Ada.Text_IO.Put_Line ("Server running at http://127.0.0.1:" &
                            Positive'Image (State.Port));
      Ada.Text_IO.Put_Line ("Press Ctrl+C to stop.");

      loop
         declare
            Channel : Socket_Type;
            From    : Sock_Addr_Type;
         begin
            Accept_Socket (Sock, Channel, From);
            Handle_Request (Channel, State);
            Close_Socket (Channel);
         end;
      end loop;

   exception
      when E : others =>
         Ada.Text_IO.Put_Line ("Server error: " &
                               Ada.Exceptions.Exception_Message (E));
         Close_Socket (Sock);
   end Start;

   procedure Send_Response
     (Channel : Socket_Type;
      Status  : String;
      Content_Type : String;
      Resp_Body : String)
   is
      Response : constant String :=
        "HTTP/1.1 " & Status & ASCII.CR & ASCII.LF &
        "Content-Type: " & Content_Type & ASCII.CR & ASCII.LF &
        "Content-Length:" & Integer'Image (Resp_Body'Length) & ASCII.CR & ASCII.LF &
        "Connection: close" & ASCII.CR & ASCII.LF &
        ASCII.CR & ASCII.LF &
        Resp_Body;
      SEA     : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Response'Length));
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      for I in Response'Range loop
         SEA (Ada.Streams.Stream_Element_Offset (I)) :=
           Ada.Streams.Stream_Element (Character'Pos (Response (I)));
      end loop;
      Send_Socket (Channel, SEA, Last);
   end Send_Response;

   function Read_Request_Line (Channel : Socket_Type) return String is
      Buffer : String (1 .. 4096);
      Last   : Natural := 0;
      SEA    : Ada.Streams.Stream_Element_Array (1 .. 1);
      Len    : Ada.Streams.Stream_Element_Offset;
   begin
      loop
         Receive_Socket (Channel, SEA, Len);
         exit when Len < SEA'First;
         Last := Last + 1;
         Buffer (Last) := Character'Val (SEA (SEA'First));
         exit when Last >= 2 and then
           Buffer (Last - 1) = ASCII.CR and then
           Buffer (Last) = ASCII.LF;
         exit when Last >= Buffer'Length;
      end loop;
      if Last < 2 then
         return "";
      end if;
      return Buffer (1 .. Last - 2);
   end Read_Request_Line;

   function Get_Path (Request_Line : String) return String is
      Start : Natural := 0;
      Fin   : Natural := 0;
   begin
      for I in Request_Line'Range loop
         if Request_Line (I) = ' ' then
            if Start = 0 then
               Start := I + 1;
            else
               Fin := I - 1;
               exit;
            end if;
         end if;
      end loop;
      if Start > 0 and Fin >= Start then
         return Request_Line (Start .. Fin);
      end if;
      return "";
   end Get_Path;

   procedure Handle_Request
     (Channel  : Socket_Type;
      State    : Server_State)
   is
      Request : constant String := Read_Request_Line (Channel);
      Path    : constant String := Get_Path (Request);
   begin
      -- Drain remaining request headers
      declare
         Line : String := Read_Request_Line (Channel);
      begin
         while Line'Length > 0 loop
            Line := Read_Request_Line (Channel);
         end loop;
      end;

      if Path = "/" then
         Send_Response (Channel, "200 OK", "text/html",
           Adacovex.Renderers.HTML.Render_Dashboard
             (State.Doc_Metrics, State.Proof, State.Tests,
              State.DAL_Assess, State.Packages, State.Pkg_Count));
      elsif Path = "/badge/spark.svg" then
         Send_Response (Channel, "200 OK", "image/svg+xml",
           Adacovex.Renderers.SVG.Render_SPARK_Badge (State.Proof.Level));
      elsif Path = "/badge/tests.svg" then
         Send_Response (Channel, "200 OK", "image/svg+xml",
           Adacovex.Renderers.SVG.Render_Tests_Badge (State.Tests));
      elsif Path = "/badge/do178c.svg" then
         Send_Response (Channel, "200 OK", "image/svg+xml",
           Adacovex.Renderers.SVG.Render_DO178C_Badge (State.DAL_Assess));
      elsif Path = "/api/metrics" then
         Send_Response (Channel, "200 OK", "application/json",
           Adacovex.Renderers.HTML.Render_Metrics_JSON
             (State.Doc_Metrics, State.Proof, State.Tests, State.DAL_Assess));
      else
         Send_Response (Channel, "404 Not Found", "text/plain",
           "Not Found: " & Path);
      end if;
   end Handle_Request;

end Adacovex.Server.HTTP;
