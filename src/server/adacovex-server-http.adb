with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Streams;
with GNAT.Sockets;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.HTML;

package body Adacovex.Server.HTTP is

   use GNAT.Sockets;
   use type Ada.Streams.Stream_Element_Offset;

   Max_Workers : constant := 4;

   procedure Send_Response
     (Channel      : Socket_Type;
      Status       : String;
      Content_Type : String;
      Resp_Body    : String;
      Keep_Alive   : Boolean);

   function Read_Request_Line (Channel : Socket_Type) return String;

   function Get_Path (Request_Line : String) return String;

   function To_Lower (C : Character) return Character;

   function Is_Header (Line : String; Name : String) return Boolean;

   procedure Handle_Request
     (Channel : Socket_Type; State : Server_State; Keep_Alive : out Boolean);

   function To_Lower (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val (Character'Pos (C) + 32);
      end if;
      return C;
   end To_Lower;

   function Is_Header (Line : String; Name : String) return Boolean is
   begin
      if Line'Length < Name'Length then
         return False;
      end if;
      for I in Name'Range loop
         if To_Lower (Line (Line'First + (I - Name'First)))
           /= To_Lower (Name (I))
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Header;

    procedure Start (State : Server_State) is
       Listener : Socket_Type;
       Addr     : Sock_Addr_Type;
       Family   : Family_Type := Family_Inet;

       Svr_State : Server_State := State;
       Running   : Boolean := True with Atomic;

      task type Worker is
         entry Start;
      end Worker;

       task body Worker is
          Channel    : Socket_Type;
          From       : Sock_Addr_Type;
          KA         : Boolean;
          Backoff_Ct : Natural := 0;
       begin
          accept Start;
          while Running loop
             begin
                Accept_Socket (Listener, Channel, From);
                Backoff_Ct := 0;
                loop
                   Handle_Request (Channel, Svr_State, KA);
                   exit when not KA;
                end loop;
                Close_Socket (Channel);
             exception
                when GNAT.Sockets.Socket_Error =>
                   Backoff_Ct := Backoff_Ct + 1;
                   delay 0.1;
                   if Backoff_Ct > 100 then
                      Running := False;
                      exit;
                   end if;
             end;
          end loop;
       end Worker;

      Workers : array (1 .. Max_Workers) of Worker;

    begin
       Ada.Text_IO.Put_Line
         ("Starting adacovex HTTP server on port"
          & Positive'Image (State.Port)
          & " with"
          & Positive'Image (Max_Workers)
          & " workers...");

       Create_Socket (Listener, Family, Socket_Stream);
       Set_Socket_Option (Listener, Socket_Level, (Reuse_Address, True));

       Addr.Addr := GNAT.Sockets.Addresses (Get_Host_By_Name ("127.0.0.1"), 1);
       Addr.Port := Port_Type (State.Port);
       Bind_Socket (Listener, Addr);
       Listen_Socket (Listener);

       Ada.Text_IO.Put_Line
         ("Server running at http://127.0.0.1:" & Positive'Image (State.Port));
       Ada.Text_IO.Put_Line ("Press Ctrl+C to stop.");

       for W of Workers loop
          W.Start;
       end loop;

       while Running loop
          delay 1.0;
       end loop;

       Close_Socket (Listener);

    exception
       when E : others =>
          Running := False;
          Ada.Text_IO.Put_Line
            ("Server error: " & Ada.Exceptions.Exception_Message (E));
          Close_Socket (Listener);
    end Start;

   procedure Send_Response
     (Channel      : Socket_Type;
      Status       : String;
      Content_Type : String;
      Resp_Body    : String;
      Keep_Alive   : Boolean)
   is
      Conn_Val : constant String :=
        (if Keep_Alive then "keep-alive" else "close");
      Response : constant String :=
        "HTTP/1.1 "
        & Status
        & ASCII.CR
        & ASCII.LF
        & "Content-Type: "
        & Content_Type
        & ASCII.CR
        & ASCII.LF
        & "Content-Length:"
        & Integer'Image (Resp_Body'Length)
        & ASCII.CR
        & ASCII.LF
        & "Connection: "
        & Conn_Val
        & ASCII.CR
        & ASCII.LF
        & ASCII.CR
        & ASCII.LF
        & Resp_Body;
      SEA      :
        Ada.Streams.Stream_Element_Array
          (1 .. Ada.Streams.Stream_Element_Offset (Response'Length));
      Last     : Ada.Streams.Stream_Element_Offset;
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
         exit when
           Last >= 2
           and then Buffer (Last - 1) = ASCII.CR
           and then Buffer (Last) = ASCII.LF;
         exit when Last >= Buffer'Length;
      end loop;
       if Last < 2 or else Last >= Buffer'Length then
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
     (Channel : Socket_Type; State : Server_State; Keep_Alive : out Boolean)
   is
      Request : constant String := Read_Request_Line (Channel);
      Path    : constant String := Get_Path (Request);
      Is_KA   : Boolean;
      CLen    : Natural := 0;
   begin
      if Request'Length = 0 then
         Keep_Alive := False;
         return;
      end if;

      --  Determine HTTP version: HTTP/1.1 defaults to keep-alive
      if Request'Length >= 8
        and then Request (Request'Last - 7 .. Request'Last) = "HTTP/1.1"
      then
         Is_KA := True;
      else
         Is_KA := False;
      end if;

      --  Read headers
      loop
         declare
            Hdr : constant String := Read_Request_Line (Channel);
         begin
            exit when Hdr'Length = 0;

            if Is_Header (Hdr, "Connection") then
               for I in Hdr'Range loop
                  if Hdr (I) = ':' then
                     declare
                        Pos : Natural := I + 1;
                     begin
                        while Pos <= Hdr'Last and then Hdr (Pos) = ' ' loop
                           Pos := Pos + 1;
                        end loop;
                        if Hdr'Last - Pos + 1 >= 5 then
                           declare
                              Val : String renames Hdr (Pos .. Hdr'Last);
                           begin
                              if Val'Length >= 5
                                and then (To_Lower (Val (Val'First)) = 'c')
                                and then To_Lower (Val (Val'First + 1)) = 'l'
                                and then To_Lower (Val (Val'First + 2)) = 'o'
                                and then To_Lower (Val (Val'First + 3)) = 's'
                                and then To_Lower (Val (Val'First + 4)) = 'e'
                              then
                                 Is_KA := False;
                              end if;
                           end;
                        end if;
                     end;
                     exit;
                  end if;
               end loop;

            elsif Is_Header (Hdr, "Content-Length") then
               for I in Hdr'Range loop
                  if Hdr (I) = ':' then
                     declare
                        Pos : Natural := I + 1;
                     begin
                        while Pos <= Hdr'Last and then Hdr (Pos) = ' ' loop
                           Pos := Pos + 1;
                        end loop;
                        CLen := 0;
                        while Pos <= Hdr'Last and then Hdr (Pos) in '0' .. '9'
                        loop
                           CLen :=
                             CLen
                             * 10
                             + (Character'Pos (Hdr (Pos))
                                - Character'Pos ('0'));
                           Pos := Pos + 1;
                        end loop;
                     end;
                     exit;
                  end if;
               end loop;
            end if;
         end;
      end loop;

      --  Read and discard request body if present
      while CLen > 0 loop
         declare
            To_Read   : constant Natural := Natural'Min (CLen, 4096);
            Body_SEA  :
              Ada.Streams.Stream_Element_Array
                (1 .. Ada.Streams.Stream_Element_Offset (To_Read));
            Body_Last : Ada.Streams.Stream_Element_Offset;
         begin
            Receive_Socket (Channel, Body_SEA, Body_Last);
            exit when Body_Last < Body_SEA'First;
            CLen := CLen - Natural (Body_Last);
         end;
      end loop;

      Keep_Alive := Is_KA;

      if Path = "/" then
         Send_Response
           (Channel,
            "200 OK",
            "text/html",
            Adacovex.Renderers.HTML.Render_Dashboard
              (State.Doc_Metrics,
               State.Proof,
               State.Tests,
               State.DAL_Assess,
               State.Packages),
            Is_KA);
      elsif Path = "/badge/spark.svg" then
         Send_Response
           (Channel,
            "200 OK",
            "image/svg+xml",
            Adacovex.Renderers.SVG.Render_SPARK_Badge (State.Proof.Level),
            Is_KA);
      elsif Path = "/badge/tests.svg" then
         Send_Response
           (Channel,
            "200 OK",
            "image/svg+xml",
            Adacovex.Renderers.SVG.Render_Tests_Badge (State.Tests),
            Is_KA);
      elsif Path = "/badge/do178c.svg" then
         Send_Response
           (Channel,
            "200 OK",
            "image/svg+xml",
            Adacovex.Renderers.SVG.Render_DO178C_Badge (State.DAL_Assess),
            Is_KA);
      elsif Path = "/api/metrics" then
         Send_Response
           (Channel,
            "200 OK",
            "application/json",
            Adacovex.Renderers.HTML.Render_Metrics_JSON
              (State.Doc_Metrics, State.Proof, State.Tests, State.DAL_Assess),
            Is_KA);
      else
         Send_Response
           (Channel,
            "404 Not Found",
            "text/plain",
            "Not Found: " & Path,
            Is_KA);
      end if;
   end Handle_Request;

end Adacovex.Server.HTTP;
