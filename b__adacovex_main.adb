pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__adacovex_main.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__adacovex_main.adb");
pragma Suppress (Overflow_Check);

with System.Restrictions;
with Ada.Exceptions;

package body ada_main is

   E075 : Short_Integer; pragma Import (Ada, E075, "system__os_lib_E");
   E008 : Short_Integer; pragma Import (Ada, E008, "ada__exceptions_E");
   E013 : Short_Integer; pragma Import (Ada, E013, "system__soft_links_E");
   E024 : Short_Integer; pragma Import (Ada, E024, "system__exception_table_E");
   E040 : Short_Integer; pragma Import (Ada, E040, "ada__containers_E");
   E070 : Short_Integer; pragma Import (Ada, E070, "ada__io_exceptions_E");
   E031 : Short_Integer; pragma Import (Ada, E031, "ada__numerics_E");
   E055 : Short_Integer; pragma Import (Ada, E055, "ada__strings_E");
   E057 : Short_Integer; pragma Import (Ada, E057, "ada__strings__maps_E");
   E060 : Short_Integer; pragma Import (Ada, E060, "ada__strings__maps__constants_E");
   E045 : Short_Integer; pragma Import (Ada, E045, "interfaces__c_E");
   E025 : Short_Integer; pragma Import (Ada, E025, "system__exceptions_E");
   E086 : Short_Integer; pragma Import (Ada, E086, "system__object_reader_E");
   E050 : Short_Integer; pragma Import (Ada, E050, "system__dwarf_lines_E");
   E020 : Short_Integer; pragma Import (Ada, E020, "system__soft_links__initialize_E");
   E039 : Short_Integer; pragma Import (Ada, E039, "system__traceback__symbolic_E");
   E162 : Short_Integer; pragma Import (Ada, E162, "ada__assertions_E");
   E115 : Short_Integer; pragma Import (Ada, E115, "ada__strings__utf_encoding_E");
   E123 : Short_Integer; pragma Import (Ada, E123, "ada__tags_E");
   E113 : Short_Integer; pragma Import (Ada, E113, "ada__strings__text_buffers_E");
   E262 : Short_Integer; pragma Import (Ada, E262, "gnat_E");
   E111 : Short_Integer; pragma Import (Ada, E111, "interfaces__c__strings_E");
   E131 : Short_Integer; pragma Import (Ada, E131, "ada__streams_E");
   E147 : Short_Integer; pragma Import (Ada, E147, "system__file_control_block_E");
   E142 : Short_Integer; pragma Import (Ada, E142, "system__finalization_root_E");
   E140 : Short_Integer; pragma Import (Ada, E140, "ada__finalization_E");
   E139 : Short_Integer; pragma Import (Ada, E139, "system__file_io_E");
   E174 : Short_Integer; pragma Import (Ada, E174, "system__storage_pools_E");
   E177 : Short_Integer; pragma Import (Ada, E177, "system__storage_pools__subpools_E");
   E211 : Short_Integer; pragma Import (Ada, E211, "ada__strings__unbounded_E");
   E254 : Short_Integer; pragma Import (Ada, E254, "system__task_info_E");
   E006 : Short_Integer; pragma Import (Ada, E006, "ada__calendar_E");
   E238 : Short_Integer; pragma Import (Ada, E238, "ada__calendar__delays_E");
   E196 : Short_Integer; pragma Import (Ada, E196, "ada__calendar__time_zones_E");
   E129 : Short_Integer; pragma Import (Ada, E129, "ada__text_io_E");
   E248 : Short_Integer; pragma Import (Ada, E248, "system__task_primitives__operations_E");
   E240 : Short_Integer; pragma Import (Ada, E240, "ada__real_time_E");
   E170 : Short_Integer; pragma Import (Ada, E170, "system__pool_global_E");
   E264 : Short_Integer; pragma Import (Ada, E264, "gnat__sockets_E");
   E267 : Short_Integer; pragma Import (Ada, E267, "gnat__sockets__poll_E");
   E275 : Short_Integer; pragma Import (Ada, E275, "gnat__sockets__thin_common_E");
   E269 : Short_Integer; pragma Import (Ada, E269, "gnat__sockets__thin_E");
   E214 : Short_Integer; pragma Import (Ada, E214, "system__regexp_E");
   E192 : Short_Integer; pragma Import (Ada, E192, "ada__directories_E");
   E285 : Short_Integer; pragma Import (Ada, E285, "system__tasking__initialization_E");
   E293 : Short_Integer; pragma Import (Ada, E293, "system__tasking__protected_objects_E");
   E295 : Short_Integer; pragma Import (Ada, E295, "system__tasking__protected_objects__entries_E");
   E299 : Short_Integer; pragma Import (Ada, E299, "system__tasking__queuing_E");
   E303 : Short_Integer; pragma Import (Ada, E303, "system__tasking__stages_E");
   E164 : Short_Integer; pragma Import (Ada, E164, "adacovex__types_E");
   E218 : Short_Integer; pragma Import (Ada, E218, "adacovex__config_E");
   E158 : Short_Integer; pragma Import (Ada, E158, "adacovex__parsers__do178c_E");
   E220 : Short_Integer; pragma Import (Ada, E220, "adacovex__parsers__gnatprove_E");
   E190 : Short_Integer; pragma Import (Ada, E190, "adacovex__parsers__source_E");
   E151 : Short_Integer; pragma Import (Ada, E151, "adacovex__compliance__dal_E");
   E222 : Short_Integer; pragma Import (Ada, E222, "adacovex__parsers__tests_E");
   E225 : Short_Integer; pragma Import (Ada, E225, "adacovex__renderers__ansi_E");
   E261 : Short_Integer; pragma Import (Ada, E261, "adacovex__renderers__html_E");
   E227 : Short_Integer; pragma Import (Ada, E227, "adacovex__renderers__markdown_E");
   E233 : Short_Integer; pragma Import (Ada, E233, "adacovex__renderers__svg_E");
   E236 : Short_Integer; pragma Import (Ada, E236, "adacovex__server__http_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      E164 := E164 - 1;
      declare
         procedure F1;
         pragma Import (Ada, F1, "adacovex__types__finalize_spec");
      begin
         F1;
      end;
      E295 := E295 - 1;
      declare
         procedure F2;
         pragma Import (Ada, F2, "system__tasking__protected_objects__entries__finalize_spec");
      begin
         F2;
      end;
      declare
         procedure F3;
         pragma Import (Ada, F3, "ada__directories__finalize_body");
      begin
         E192 := E192 - 1;
         F3;
      end;
      declare
         procedure F4;
         pragma Import (Ada, F4, "ada__directories__finalize_spec");
      begin
         F4;
      end;
      E214 := E214 - 1;
      declare
         procedure F5;
         pragma Import (Ada, F5, "system__regexp__finalize_spec");
      begin
         F5;
      end;
      declare
         procedure F6;
         pragma Import (Ada, F6, "gnat__sockets__finalize_body");
      begin
         E264 := E264 - 1;
         F6;
      end;
      declare
         procedure F7;
         pragma Import (Ada, F7, "gnat__sockets__finalize_spec");
      begin
         F7;
      end;
      E170 := E170 - 1;
      declare
         procedure F8;
         pragma Import (Ada, F8, "system__pool_global__finalize_spec");
      begin
         F8;
      end;
      E129 := E129 - 1;
      declare
         procedure F9;
         pragma Import (Ada, F9, "ada__text_io__finalize_spec");
      begin
         F9;
      end;
      E211 := E211 - 1;
      declare
         procedure F10;
         pragma Import (Ada, F10, "ada__strings__unbounded__finalize_spec");
      begin
         F10;
      end;
      E177 := E177 - 1;
      declare
         procedure F11;
         pragma Import (Ada, F11, "system__storage_pools__subpools__finalize_spec");
      begin
         F11;
      end;
      declare
         procedure F12;
         pragma Import (Ada, F12, "system__file_io__finalize_body");
      begin
         E139 := E139 - 1;
         F12;
      end;
      declare
         procedure Reraise_Library_Exception_If_Any;
            pragma Import (Ada, Reraise_Library_Exception_If_Any, "__gnat_reraise_library_exception_if_any");
      begin
         Reraise_Library_Exception_If_Any;
      end;
   end finalize_library;

   procedure adafinal is
      procedure s_stalib_adafinal;
      pragma Import (Ada, s_stalib_adafinal, "system__standard_library__adafinal");

      procedure Runtime_Finalize;
      pragma Import (C, Runtime_Finalize, "__gnat_runtime_finalize");

   begin
      if not Is_Elaborated then
         return;
      end if;
      Is_Elaborated := False;
      Runtime_Finalize;
      s_stalib_adafinal;
   end adafinal;

   type No_Param_Proc is access procedure;
   pragma Favor_Top_Level (No_Param_Proc);

   procedure adainit is
      Main_Priority : Integer;
      pragma Import (C, Main_Priority, "__gl_main_priority");
      Time_Slice_Value : Integer;
      pragma Import (C, Time_Slice_Value, "__gl_time_slice_val");
      WC_Encoding : Character;
      pragma Import (C, WC_Encoding, "__gl_wc_encoding");
      Locking_Policy : Character;
      pragma Import (C, Locking_Policy, "__gl_locking_policy");
      Queuing_Policy : Character;
      pragma Import (C, Queuing_Policy, "__gl_queuing_policy");
      Task_Dispatching_Policy : Character;
      pragma Import (C, Task_Dispatching_Policy, "__gl_task_dispatching_policy");
      Priority_Specific_Dispatching : System.Address;
      pragma Import (C, Priority_Specific_Dispatching, "__gl_priority_specific_dispatching");
      Num_Specific_Dispatching : Integer;
      pragma Import (C, Num_Specific_Dispatching, "__gl_num_specific_dispatching");
      Main_CPU : Integer;
      pragma Import (C, Main_CPU, "__gl_main_cpu");
      Interrupt_States : System.Address;
      pragma Import (C, Interrupt_States, "__gl_interrupt_states");
      Num_Interrupt_States : Integer;
      pragma Import (C, Num_Interrupt_States, "__gl_num_interrupt_states");
      Unreserve_All_Interrupts : Integer;
      pragma Import (C, Unreserve_All_Interrupts, "__gl_unreserve_all_interrupts");
      Exception_Tracebacks : Integer;
      pragma Import (C, Exception_Tracebacks, "__gl_exception_tracebacks");
      Detect_Blocking : Integer;
      pragma Import (C, Detect_Blocking, "__gl_detect_blocking");
      Default_Stack_Size : Integer;
      pragma Import (C, Default_Stack_Size, "__gl_default_stack_size");
      Default_Secondary_Stack_Size : System.Parameters.Size_Type;
      pragma Import (C, Default_Secondary_Stack_Size, "__gnat_default_ss_size");
      Bind_Env_Addr : System.Address;
      pragma Import (C, Bind_Env_Addr, "__gl_bind_env_addr");
      Interrupts_Default_To_System : Integer;
      pragma Import (C, Interrupts_Default_To_System, "__gl_interrupts_default_to_system");

      procedure Runtime_Initialize (Install_Handler : Integer);
      pragma Import (C, Runtime_Initialize, "__gnat_runtime_initialize");

      procedure Tasking_Runtime_Initialize;
      pragma Import (C, Tasking_Runtime_Initialize, "__gnat_tasking_runtime_initialize");

      Finalize_Library_Objects : No_Param_Proc;
      pragma Import (C, Finalize_Library_Objects, "__gnat_finalize_library_objects");
      Binder_Sec_Stacks_Count : Natural;
      pragma Import (Ada, Binder_Sec_Stacks_Count, "__gnat_binder_ss_count");
      Default_Sized_SS_Pool : System.Address;
      pragma Import (Ada, Default_Sized_SS_Pool, "__gnat_default_ss_pool");

   begin
      if Is_Elaborated then
         return;
      end if;
      Is_Elaborated := True;
      Main_Priority := -1;
      Time_Slice_Value := -1;
      WC_Encoding := '8';
      Locking_Policy := ' ';
      Queuing_Policy := ' ';
      Task_Dispatching_Policy := ' ';
      System.Restrictions.Run_Time_Restrictions :=
        (Set =>
          (False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, True, False, False, False, False, 
           False, False, False, False, False, False, False, False, 
           False, False, False, False),
         Value => (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
         Violated =>
          (False, False, False, False, True, True, False, False, 
           True, False, False, True, True, True, True, False, 
           False, False, False, True, False, False, True, True, 
           False, True, True, False, True, True, True, True, 
           False, False, False, False, False, False, True, False, 
           False, True, False, True, False, False, True, False, 
           True, False, True, False, False, False, True, False, 
           True, False, False, False, False, True, False, False, 
           False, True, False, True, True, True, False, False, 
           True, False, True, True, True, False, True, True, 
           False, True, True, True, True, False, False, False, 
           False, False, False, False, False, False, False, True, 
           True, False, False, False),
         Count => (0, 0, 0, 0, 0, 1, 1, 0, 0, 0),
         Unknown => (False, False, False, False, False, False, True, False, False, False));
      Priority_Specific_Dispatching :=
        Local_Priority_Specific_Dispatching'Address;
      Num_Specific_Dispatching := 0;
      Main_CPU := -1;
      Interrupt_States := Local_Interrupt_States'Address;
      Num_Interrupt_States := 0;
      Unreserve_All_Interrupts := 0;
      Exception_Tracebacks := 1;
      Detect_Blocking := 0;
      Default_Stack_Size := -1;

      ada_main'Elab_Body;
      Default_Secondary_Stack_Size := System.Parameters.Runtime_Default_Sec_Stack_Size;
      Binder_Sec_Stacks_Count := 1;
      Default_Sized_SS_Pool := Sec_Default_Sized_Stacks'Address;

      Runtime_Initialize (1);
      Tasking_Runtime_Initialize;

      Finalize_Library_Objects := finalize_library'access;

      Ada.Exceptions'Elab_Spec;
      System.Soft_Links'Elab_Spec;
      System.Exception_Table'Elab_Body;
      E024 := E024 + 1;
      Ada.Containers'Elab_Spec;
      E040 := E040 + 1;
      Ada.Io_Exceptions'Elab_Spec;
      E070 := E070 + 1;
      Ada.Numerics'Elab_Spec;
      E031 := E031 + 1;
      Ada.Strings'Elab_Spec;
      E055 := E055 + 1;
      Ada.Strings.Maps'Elab_Spec;
      E057 := E057 + 1;
      Ada.Strings.Maps.Constants'Elab_Spec;
      E060 := E060 + 1;
      Interfaces.C'Elab_Spec;
      E045 := E045 + 1;
      System.Exceptions'Elab_Spec;
      E025 := E025 + 1;
      System.Object_Reader'Elab_Spec;
      E086 := E086 + 1;
      System.Dwarf_Lines'Elab_Spec;
      E050 := E050 + 1;
      System.Os_Lib'Elab_Body;
      E075 := E075 + 1;
      System.Soft_Links.Initialize'Elab_Body;
      E020 := E020 + 1;
      E013 := E013 + 1;
      System.Traceback.Symbolic'Elab_Body;
      E039 := E039 + 1;
      E008 := E008 + 1;
      Ada.Assertions'Elab_Spec;
      E162 := E162 + 1;
      Ada.Strings.Utf_Encoding'Elab_Spec;
      E115 := E115 + 1;
      Ada.Tags'Elab_Spec;
      Ada.Tags'Elab_Body;
      E123 := E123 + 1;
      Ada.Strings.Text_Buffers'Elab_Spec;
      E113 := E113 + 1;
      Gnat'Elab_Spec;
      E262 := E262 + 1;
      Interfaces.C.Strings'Elab_Spec;
      E111 := E111 + 1;
      Ada.Streams'Elab_Spec;
      E131 := E131 + 1;
      System.File_Control_Block'Elab_Spec;
      E147 := E147 + 1;
      System.Finalization_Root'Elab_Spec;
      E142 := E142 + 1;
      Ada.Finalization'Elab_Spec;
      E140 := E140 + 1;
      System.File_Io'Elab_Body;
      E139 := E139 + 1;
      System.Storage_Pools'Elab_Spec;
      E174 := E174 + 1;
      System.Storage_Pools.Subpools'Elab_Spec;
      E177 := E177 + 1;
      Ada.Strings.Unbounded'Elab_Spec;
      E211 := E211 + 1;
      System.Task_Info'Elab_Spec;
      E254 := E254 + 1;
      Ada.Calendar'Elab_Spec;
      Ada.Calendar'Elab_Body;
      E006 := E006 + 1;
      Ada.Calendar.Delays'Elab_Body;
      E238 := E238 + 1;
      Ada.Calendar.Time_Zones'Elab_Spec;
      E196 := E196 + 1;
      Ada.Text_Io'Elab_Spec;
      Ada.Text_Io'Elab_Body;
      E129 := E129 + 1;
      System.Task_Primitives.Operations'Elab_Body;
      E248 := E248 + 1;
      Ada.Real_Time'Elab_Spec;
      Ada.Real_Time'Elab_Body;
      E240 := E240 + 1;
      System.Pool_Global'Elab_Spec;
      E170 := E170 + 1;
      Gnat.Sockets'Elab_Spec;
      Gnat.Sockets.Thin_Common'Elab_Spec;
      E275 := E275 + 1;
      E269 := E269 + 1;
      Gnat.Sockets'Elab_Body;
      E264 := E264 + 1;
      E267 := E267 + 1;
      System.Regexp'Elab_Spec;
      E214 := E214 + 1;
      Ada.Directories'Elab_Spec;
      Ada.Directories'Elab_Body;
      E192 := E192 + 1;
      System.Tasking.Initialization'Elab_Body;
      E285 := E285 + 1;
      System.Tasking.Protected_Objects'Elab_Body;
      E293 := E293 + 1;
      System.Tasking.Protected_Objects.Entries'Elab_Spec;
      E295 := E295 + 1;
      System.Tasking.Queuing'Elab_Body;
      E299 := E299 + 1;
      System.Tasking.Stages'Elab_Body;
      E303 := E303 + 1;
      Adacovex.Types'Elab_Spec;
      E164 := E164 + 1;
      E218 := E218 + 1;
      E158 := E158 + 1;
      E220 := E220 + 1;
      E190 := E190 + 1;
      E151 := E151 + 1;
      E222 := E222 + 1;
      E225 := E225 + 1;
      E261 := E261 + 1;
      E227 := E227 + 1;
      E233 := E233 + 1;
      E236 := E236 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_adacovex_main");

   function main
     (argc : Integer;
      argv : System.Address;
      envp : System.Address)
      return Integer
   is
      procedure Initialize (Addr : System.Address);
      pragma Import (C, Initialize, "__gnat_initialize");

      procedure Finalize;
      pragma Import (C, Finalize, "__gnat_finalize");
      SEH : aliased array (1 .. 2) of Integer;

      Ensure_Reference : aliased System.Address := Ada_Main_Program_Name'Address;
      pragma Volatile (Ensure_Reference);

   begin
      if gnat_argc = 0 then
         gnat_argc := argc;
         gnat_argv := argv;
      end if;
      gnat_envp := envp;

      Initialize (SEH'Address);
      adainit;
      Ada_Main_Program;
      adafinal;
      Finalize;
      return (gnat_exit_status);
   end;

--  BEGIN Object file/option list
   --   /home/data/Desktop/projects/adacovex/adacovex.o
   --   /home/data/Desktop/projects/adacovex/adacovex-compliance.o
   --   /home/data/Desktop/projects/adacovex/adacovex-parsers.o
   --   /home/data/Desktop/projects/adacovex/adacovex-renderers.o
   --   /home/data/Desktop/projects/adacovex/adacovex-server.o
   --   /home/data/Desktop/projects/adacovex/adacovex-types.o
   --   /home/data/Desktop/projects/adacovex/adacovex-config.o
   --   /home/data/Desktop/projects/adacovex/adacovex-parsers-do178c.o
   --   /home/data/Desktop/projects/adacovex/adacovex-parsers-gnatprove.o
   --   /home/data/Desktop/projects/adacovex/adacovex-parsers-source.o
   --   /home/data/Desktop/projects/adacovex/adacovex-compliance-dal.o
   --   /home/data/Desktop/projects/adacovex/adacovex-parsers-tests.o
   --   /home/data/Desktop/projects/adacovex/adacovex-renderers-ansi.o
   --   /home/data/Desktop/projects/adacovex/adacovex-renderers-html.o
   --   /home/data/Desktop/projects/adacovex/adacovex-renderers-markdown.o
   --   /home/data/Desktop/projects/adacovex/adacovex-renderers-svg.o
   --   /home/data/Desktop/projects/adacovex/adacovex-server-http.o
   --   /home/data/Desktop/projects/adacovex/adacovex_main.o
   --   -L/home/data/Desktop/projects/adacovex/
   --   -L/home/data/Desktop/projects/adacovex/
   --   -L/home/data/.local/share/alire/toolchains/gnat_native_15.2.1_4640d4b3/lib/gcc/x86_64-pc-linux-gnu/15.2.0/adalib/
   --   -static
   --   -lgnarl
   --   -lgnat
   --   -lrt
   --   -lpthread
   --   -ldl
--  END Object file/option list   

end ada_main;
