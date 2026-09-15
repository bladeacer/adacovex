with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Streams;
with GNAT.Sockets;
with Adacovex.Docs_Template;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.HTML;

package body Adacovex.Server.HTTP is

   use GNAT.Sockets;
   use type Ada.Streams.Stream_Element_Offset;

   --  Upper bound for the static task array. --serve-workers requests a
   --  smaller pool; the array is sized to the cap and only the requested
   --  number of tasks are started.
   Max_Workers_Cap : constant := 256;

   procedure Send_Response
     (Channel      : Socket_Type;
      Status       : String;
      Content_Type : String;
      Resp_Body    : String;
      Keep_Alive   : Boolean);

   procedure Send_Redirect
     (Channel : Socket_Type; Location : String; Keep_Alive : Boolean);

   function Get_Path (Request_Line : String) return String;

   function To_Lower (C : Character) return Character;

   function Is_Header (Line : String; Name : String) return Boolean;

   --  A per-connection receive buffer. Request lines and headers are read
   --  through it so one Receive_Socket call fills many lines: reading one
   --  byte per syscall made a typical request (~300 bytes of request line
   --  plus headers) cost ~300 receive syscalls on the worker. The reader
   --  pulls 4 KiB at a time and hands out complete CRLF-terminated lines
   --  from the buffer, refilling only when it runs dry. A buffer lives in
   --  one Worker task for the life of one keep-alive connection, so it
   --  needs no locking.
   type Line_Reader is limited record
      Channel : Socket_Type;
      Buffer  : String (1 .. 4096);
      Pos     : Natural := 1;  --  next unread byte in Buffer
      Filled  : Natural := 0;  --  bytes valid in Buffer (0 = refill needed)
      Eof     : Boolean := False;
   end record;

   --  Read one CRLF-terminated line through Reader. Returns "" on EOF,
   --  socket error, or an over-long line. The CRLF is stripped.
   procedure Read_Line
     (Reader : in out Line_Reader; Line : out String; Last : out Natural);

   --  The docs asset key for a routed path: strip the "/docs" prefix (the
   --  dashboard links carry a trailing slash) and map the bare "/docs" to
   --  the manual index page.
   function Docs_Subpath (Path : String) return String;

   procedure Handle_Request
     (Channel : Socket_Type; State : Server_State; Keep_Alive : out Boolean);

   function To_Lower (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val (Character'Pos (C) + 32);
      end if;
      return C;
   end To_Lower;

   --  The docs asset key for a routed path. The path is one of "/docs",
   --  "/docs/", or "/docs/<subpath>"; the table is keyed by book-relative
   --  paths ("index.html", "css/general.css", ...), so the prefix is
   --  stripped and the bare manual root maps to the index page.
   --  Path is a slice of the request line, so its First is not 1: the
   --  "/docs/" prefix is exactly six characters wherever the slice starts.
   function Docs_Subpath (Path : String) return String is
   begin
      if Path = "/docs" or else Path = "/docs/" then
         return "index.html";
      end if;
      --  "/docs/" is six characters; the subpath starts at Path'First + 6.
      return Path (Path'First + 6 .. Path'Last);
   end Docs_Subpath;

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
      Running   : Boolean := True
      with Atomic;

      task type Worker is
         entry Start;
      end Worker;

      task body Worker is
         Channel    : Socket_Type;
         From       : Sock_Addr_Type;
         KA         : Boolean;
         Backoff_Ct : Natural := 0;
         Has_Conn   : Boolean := False;
      begin
         accept Start;
         while Running loop
            begin
               Accept_Socket (Listener, Channel, From);
               Has_Conn := True;
               Backoff_Ct := 0;
               --  Idle connections must never pin a worker: the pool is
               --  fixed-size, so idle keep-alive connections block every
               --  worker and stall the next request. A receive timeout frees
               --  the worker (and closes the socket) when a connection goes
               --  silent. The window is kept short (half a second): a
               --  browser opening a page issues many parallel asset requests,
               --  and the pool only has a few workers to serve them from the
               --  accept queue, so a long idle timeout serialises the burst
               --  behind 4 keep-alive sockets and loads pages slowly. Short
               --  means workers recycle back to Accept_Socket promptly while
               --  a quickly-reused connection still serves its burst.
               Set_Socket_Option
                 (Channel, Socket_Level, (Receive_Timeout, 0.5));
               loop
                  Handle_Request (Channel, Svr_State, KA);
                  exit when not KA;
               end loop;
               Close_Socket (Channel);
               Has_Conn := False;
            exception
               when GNAT.Sockets.Socket_Error =>
                  --  The peer vanished or the receive timeout fired on an
                  --  idle keep-alive connection: close the socket so the
                  --  worker frees instead of leaking a dead connection.
                  if Has_Conn then
                     Close_Socket (Channel);
                     Has_Conn := False;
                  end if;
                  Backoff_Ct := Backoff_Ct + 1;
                  delay 0.1;
                  if Backoff_Ct > 100 then
                     Running := False;
                     exit;
                  end if;
            end;
         end loop;
      end Worker;

      Workers : array (1 .. Max_Workers_Cap) of Worker;
      Active  : constant Positive :=
        Positive'Min (State.Workers, Max_Workers_Cap);

   begin
      Ada.Text_IO.Put_Line
        ("Starting adacovex HTTP server on port"
         & Positive'Image (State.Port)
         & " with"
         & Positive'Image (Active)
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

      for I in 1 .. Active loop
         Workers (I).Start;
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

   procedure Send_Redirect
     (Channel : Socket_Type; Location : String; Keep_Alive : Boolean)
   is
      Conn_Val : constant String :=
        (if Keep_Alive then "keep-alive" else "close");
      Response : constant String :=
        "HTTP/1.1 301 Moved Permanently"
        & ASCII.CR
        & ASCII.LF
        & "Location: "
        & Location
        & ASCII.CR
        & ASCII.LF
        & "Content-Length: 0"
        & ASCII.CR
        & ASCII.LF
        & "Connection: "
        & Conn_Val
        & ASCII.CR
        & ASCII.LF
        & ASCII.CR
        & ASCII.LF;
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
   end Send_Redirect;

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

   --  Send one docs asset with its HTTP header, streaming the body in
   --  fixed-size slices. Assets are stored gzip-compressed and base64-encoded
   --  (see tools/gen-docs.py); the generator chunks every asset into fixed
   --  small bodies so no worker task ever materialises a whole multi-megabyte
   --  body (or its stream array) on its stack. Each chunk is decoded here
   --  and streamed; when Gzipped, the raw gzip bytes go out with a
   --  `Content-Encoding: gzip` header and the browser inflates them.
   procedure Send_Asset_Response
     (Channel      : Socket_Type;
      Status       : String;
      Content_Type : String;
      Idx          : Adacovex.Docs_Template.Asset_Index;
      Gzipped      : Boolean;
      Keep_Alive   : Boolean)
   is
      Conn_Val : constant String :=
        (if Keep_Alive then "keep-alive" else "close");
      First    : constant Adacovex.Docs_Template.Body_Index :=
        Adacovex.Docs_Template.Assets (Idx).Idx;
      Total    : Natural := 0;
   begin
      for K in 0 .. Adacovex.Docs_Template.Chunk_Count (Idx) - 1 loop
         Total :=
           Total
           + Adacovex.Docs_Template.Body_Bytes
               (Adacovex.Docs_Template.Body_Index (Natural (First) + K),
                Gzipped)'Length;
      end loop;
      declare
         Response : constant String :=
           "HTTP/1.1 "
           & Status
           & ASCII.CR
           & ASCII.LF
           & "Content-Type: "
           & Content_Type
           & ASCII.CR
           & ASCII.LF
           & (if Gzipped
              then "Content-Encoding: gzip" & ASCII.CR & ASCII.LF
              else "")
           & "Content-Length:"
           & Integer'Image (Total)
           & ASCII.CR
           & ASCII.LF
           & "Connection: "
           & Conn_Val
           & ASCII.CR
           & ASCII.LF
           & ASCII.CR
           & ASCII.LF;
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
      end;
      declare
         Slice : Ada.Streams.Stream_Element_Array (1 .. 8192);
         Last  : Ada.Streams.Stream_Element_Offset;
      begin
         for K in 0 .. Adacovex.Docs_Template.Chunk_Count (Idx) - 1 loop
            declare
               B   : constant String :=
                 Adacovex.Docs_Template.Body_Bytes
                   (Adacovex.Docs_Template.Body_Index (Natural (First) + K),
                    Gzipped);
               Off : Natural := B'First;
            begin
               while Off <= B'Last loop
                  declare
                     N : constant Natural :=
                       Natural'Min (B'Last - Off + 1, Slice'Length);
                  begin
                     for I in 1 .. N loop
                        Slice (Ada.Streams.Stream_Element_Offset (I)) :=
                          Ada.Streams.Stream_Element
                            (Character'Pos (B (Off + I - 1)));
                     end loop;
                     Send_Socket
                       (Channel,
                        Slice (1 .. Ada.Streams.Stream_Element_Offset (N)),
                        Last);
                     Off := Off + N;
                  end;
               end loop;
            end;
         end loop;
      end;
   end Send_Asset_Response;

   procedure Read_Line
     (Reader : in out Line_Reader; Line : out String; Last : out Natural)
   is
      SEA : Ada.Streams.Stream_Element_Array (1 .. Reader.Buffer'Length);
      Len : Ada.Streams.Stream_Element_Offset;
   begin
      Last := 0;
      loop
         --  Refill when the buffer is drained. A receive timeout or a
         --  vanished peer surfaces here as Eof, which the caller turns
         --  into an empty line and a closed connection.
         if Reader.Pos > Reader.Filled then
            if Reader.Eof then
               return;
            end if;
            begin
               Receive_Socket (Reader.Channel, SEA, Len);
            exception
               when GNAT.Sockets.Socket_Error =>
                  Reader.Eof := True;
                  return;
            end;
            if Len < SEA'First then
               Reader.Eof := True;
               return;
            end if;
            for I in SEA'First .. Len loop
               Reader.Buffer (Reader.Buffer'First + Natural (I - SEA'First)) :=
                 Character'Val (SEA (I));
            end loop;
            Reader.Pos := Reader.Buffer'First;
            Reader.Filled := Reader.Buffer'First + Natural (Len) - 1;
         end if;

         --  Consume buffered bytes up to (and including) the CRLF terminator.
         declare
            I : Natural := Reader.Pos;
         begin
            while I <= Reader.Filled loop
               exit when Last >= Line'Last - 1;
               Last := Last + 1;
               Line (Last) := Reader.Buffer (I);
               if Last >= 2
                 and then Line (Last - 1) = ASCII.CR
                 and then Line (Last) = ASCII.LF
               then
                  Reader.Pos := I + 1;
                  Last := Last - 2;
                  return;
               end if;
               I := I + 1;
            end loop;
            --  Buffer drained without a terminator: either the line is
            --  over-long (caller's Line is full) or we must refill.
            if Last >= Line'Last - 1 then
               Reader.Eof := True;  --  signal: over-long line -> empty
               Last := 0;
               return;
            end if;
            Reader.Pos := Reader.Filled + 1;
         end;
      end loop;
   end Read_Line;

   --  Strip the query string and fragment off a request path. Returns the
   --  path up to (and excluding) the first '?' or '#'; an empty result when
   --  the query/fragment starts at the path's first character. This is
   --  routine HTTP path normalisation: browsers pass `?theme=light` and
   --  `#tab` on the same request path, and routing must ignore both.
   function Strip_Query (Path : String) return String is
      First : constant Positive := Path'First;
   begin
      if Path'Length = 0 then
         return "";
      end if;
      for I in Path'Range loop
         if Path (I) = '?' or else Path (I) = '#' then
            return Path (First .. I - 1);
         end if;
      end loop;
      return Path;
   end Strip_Query;

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

   --  Pure path-to-action routing: the socket handler below switches on the
   --  result, and the native test suite pins every route. The function is an
   --  expression function (see the spec): its body is the conditional mapping,
   --  so the mapping is proved by definition rather than case analysis.

   procedure Handle_Request
     (Channel : Socket_Type; State : Server_State; Keep_Alive : out Boolean)
   is
      Reader   : Line_Reader := (Channel => Channel, others => <>);
      LineBuf  : String (1 .. 4096);
      Last     : Natural := 0;
      Is_KA    : Boolean;
      CLen     : Natural := 0;
      Path     : String (1 .. 2048);
      Path_Len : Natural := 0;
   begin
      --  The request line: METHOD SP PATH SP HTTP/x.x CRLF. An empty line
      --  (EOF, receive timeout, or an over-long line) closes the socket.
      Read_Line (Reader, LineBuf, Last);
      if Last = 0 then
         Keep_Alive := False;
         return;
      end if;

      --  Determine HTTP version: HTTP/1.1 defaults to keep-alive
      if Last >= 8 and then LineBuf (Last - 7 .. Last) = "HTTP/1.1" then
         Is_KA := True;
      else
         Is_KA := False;
      end if;

      --  Extract the request path (the second space-separated token) into
      --  Path (1 .. Path_Len). A malformed request line closes the socket:
      --  Get_Path declared its own buffer copy below.
      declare
         Request : constant String := LineBuf (1 .. Last);
         P       : constant String := Get_Path (Request);
      begin
         if P'Length > Path'Length then
            Keep_Alive := False;
            return;
         end if;
         Path (1 .. P'Length) := P;
         Path_Len := P'Length;
      end;

      --  Read headers
      loop
         begin
            Read_Line (Reader, LineBuf, Last);
         exception
            when others =>
               Keep_Alive := False;
               return;
         end;
         exit when Last = 0;
         declare
            Hdr : constant String := LineBuf (1 .. Last);
         begin
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

      --  Route on the query-string-stripped path so `/?theme=light`,
      --  `/api/metrics?x=1` or `/api/deps#top` reach the same handler as
      --  `/`, `/api/metrics` and `/api/deps`.
      case Route (Strip_Query (Path (1 .. Path_Len))) is
         when Route_Dashboard      =>
            Send_Response
              (Channel,
               "200 OK",
               "text/html",
               Adacovex.Renderers.HTML.Render_Dashboard
                 (State.Doc_Metrics,
                  State.Proof,
                  State.Tests,
                  State.DAL_Assess,
                  State.Packages,
                  State.Graph,
                  State.All_Standards,
                  State.Theme),
               Is_KA);

         when Route_Badge_SPARK    =>
            Send_Response
              (Channel,
               "200 OK",
               "image/svg+xml",
               Adacovex.Renderers.SVG.Render_SPARK_Badge (State.Proof.Level),
               Is_KA);

         when Route_Badge_Tests    =>
            Send_Response
              (Channel,
               "200 OK",
               "image/svg+xml",
               Adacovex.Renderers.SVG.Render_Tests_Badge (State.Tests),
               Is_KA);

         when Route_Badge_DO178C   =>
            Send_Response
              (Channel,
               "200 OK",
               "image/svg+xml",
               Adacovex.Renderers.SVG.Render_Compliance_Badge
                 (State.DAL_Assess, Types.DO_178C),
               Is_KA);

         when Route_Badge_ISO26262 =>
            Send_Response
              (Channel,
               "200 OK",
               "image/svg+xml",
               Adacovex.Renderers.SVG.Render_Compliance_Badge
                 (State.DAL_Assess, Types.ISO_26262),
               Is_KA);

         when Route_Badge_IEC62304 =>
            Send_Response
              (Channel,
               "200 OK",
               "image/svg+xml",
               Adacovex.Renderers.SVG.Render_Compliance_Badge
                 (State.DAL_Assess, Types.IEC_62304),
               Is_KA);

         when Route_API_Metrics    =>
            Send_Response
              (Channel,
               "200 OK",
               "application/json",
               Adacovex.Renderers.HTML.Render_Metrics_JSON
                 (State.Doc_Metrics,
                  State.Proof,
                  State.Tests,
                  State.DAL_Assess,
                  State.All_Standards),
               Is_KA);

         when Route_API_Deps       =>
            Send_Response
              (Channel,
               "200 OK",
               "application/json",
               Adacovex.Renderers.HTML.Render_Deps_JSON (State.Graph),
               Is_KA);

         when Route_API_Endpoints  =>
            Send_Response
              (Channel,
               "200 OK",
               "application/json",
               Adacovex.Renderers.HTML.Render_Endpoints_JSON,
               Is_KA);

         when Route_Docs           =>
            --  The asset lookup must strip the query string: search result
            --  links carry `?highlight=...`, and the fragment (already
            --  stripped by the route) must not leak into the asset key.
            --  Routing already dispatched on Strip_Query (Path), so re-apply
            --  it here for the subpath so `?theme`, `?highlight`, and
            --  `#anchor` never make a requested page 404.
            declare
               Root_Path : constant String :=
                 Strip_Query (Path (1 .. Path_Len));
            begin
               if Root_Path = "/docs" then
                  --  The bare /docs URL: redirect to the trailing-slash form
                  --  so the page's relative asset links resolve against
                  --  /docs/.
                  Send_Redirect (Channel, "/docs/", Is_KA);
               else
                  declare
                     Idx : constant Natural :=
                       Adacovex.Docs_Template.Find (Docs_Subpath (Root_Path));
                  begin
                     if Idx = 0 then
                        Send_Response
                          (Channel,
                           "404 Not Found",
                           "text/plain",
                           "Not Found: " & Path (1 .. Path_Len),
                           Is_KA);
                     else
                        declare
                           A_Idx :
                             constant Adacovex.Docs_Template.Asset_Index :=
                               Adacovex.Docs_Template.Asset_Index (Idx);
                        begin
                           Send_Asset_Response
                             (Channel,
                              "200 OK",
                              Adacovex.Docs_Template.Assets (A_Idx).Mime,
                              A_Idx,
                              Adacovex.Docs_Template.Assets (A_Idx).Gzip,
                              Is_KA);
                        end;
                     end if;
                  end;
               end if;
            end;

         when Route_Not_Found      =>
            Send_Response
              (Channel,
               "404 Not Found",
               "text/plain",
               "Not Found: " & Path (1 .. Path_Len),
               Is_KA);
      end case;
   end Handle_Request;

end Adacovex.Server.HTTP;
