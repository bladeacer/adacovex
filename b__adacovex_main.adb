pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__adacovex_main.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__adacovex_main.adb");
pragma Suppress (Overflow_Check);
with Ada.Exceptions;

package body ada_main is

   E073 : Short_Integer; pragma Import (Ada, E073, "system__os_lib_E");
   E006 : Short_Integer; pragma Import (Ada, E006, "ada__exceptions_E");
   E011 : Short_Integer; pragma Import (Ada, E011, "system__soft_links_E");
   E022 : Short_Integer; pragma Import (Ada, E022, "system__exception_table_E");
   E038 : Short_Integer; pragma Import (Ada, E038, "ada__containers_E");
   E068 : Short_Integer; pragma Import (Ada, E068, "ada__io_exceptions_E");
   E029 : Short_Integer; pragma Import (Ada, E029, "ada__numerics_E");
   E053 : Short_Integer; pragma Import (Ada, E053, "ada__strings_E");
   E055 : Short_Integer; pragma Import (Ada, E055, "ada__strings__maps_E");
   E058 : Short_Integer; pragma Import (Ada, E058, "ada__strings__maps__constants_E");
   E043 : Short_Integer; pragma Import (Ada, E043, "interfaces__c_E");
   E023 : Short_Integer; pragma Import (Ada, E023, "system__exceptions_E");
   E084 : Short_Integer; pragma Import (Ada, E084, "system__object_reader_E");
   E048 : Short_Integer; pragma Import (Ada, E048, "system__dwarf_lines_E");
   E018 : Short_Integer; pragma Import (Ada, E018, "system__soft_links__initialize_E");
   E037 : Short_Integer; pragma Import (Ada, E037, "system__traceback__symbolic_E");
   E145 : Short_Integer; pragma Import (Ada, E145, "ada__assertions_E");
   E105 : Short_Integer; pragma Import (Ada, E105, "ada__strings__utf_encoding_E");
   E113 : Short_Integer; pragma Import (Ada, E113, "ada__tags_E");
   E103 : Short_Integer; pragma Import (Ada, E103, "ada__strings__text_buffers_E");
   E225 : Short_Integer; pragma Import (Ada, E225, "gnat_E");
   E242 : Short_Integer; pragma Import (Ada, E242, "interfaces__c__strings_E");
   E121 : Short_Integer; pragma Import (Ada, E121, "ada__streams_E");
   E137 : Short_Integer; pragma Import (Ada, E137, "system__file_control_block_E");
   E132 : Short_Integer; pragma Import (Ada, E132, "system__finalization_root_E");
   E130 : Short_Integer; pragma Import (Ada, E130, "ada__finalization_E");
   E129 : Short_Integer; pragma Import (Ada, E129, "system__file_io_E");
   E198 : Short_Integer; pragma Import (Ada, E198, "system__storage_pools_E");
   E250 : Short_Integer; pragma Import (Ada, E250, "system__storage_pools__subpools_E");
   E185 : Short_Integer; pragma Import (Ada, E185, "ada__strings__unbounded_E");
   E160 : Short_Integer; pragma Import (Ada, E160, "ada__calendar_E");
   E234 : Short_Integer; pragma Import (Ada, E234, "ada__calendar__delays_E");
   E166 : Short_Integer; pragma Import (Ada, E166, "ada__calendar__time_zones_E");
   E119 : Short_Integer; pragma Import (Ada, E119, "ada__text_io_E");
   E246 : Short_Integer; pragma Import (Ada, E246, "system__pool_global_E");
   E227 : Short_Integer; pragma Import (Ada, E227, "gnat__sockets_E");
   E230 : Short_Integer; pragma Import (Ada, E230, "gnat__sockets__poll_E");
   E240 : Short_Integer; pragma Import (Ada, E240, "gnat__sockets__thin_common_E");
   E232 : Short_Integer; pragma Import (Ada, E232, "gnat__sockets__thin_E");
   E196 : Short_Integer; pragma Import (Ada, E196, "system__regexp_E");
   E158 : Short_Integer; pragma Import (Ada, E158, "ada__directories_E");
   E154 : Short_Integer; pragma Import (Ada, E154, "adacovex__types_E");
   E200 : Short_Integer; pragma Import (Ada, E200, "adacovex__config_E");
   E152 : Short_Integer; pragma Import (Ada, E152, "adacovex__parsers__do178c_E");
   E206 : Short_Integer; pragma Import (Ada, E206, "adacovex__parsers__gnatprove_E");
   E156 : Short_Integer; pragma Import (Ada, E156, "adacovex__parsers__source_E");
   E141 : Short_Integer; pragma Import (Ada, E141, "adacovex__compliance__dal_E");
   E208 : Short_Integer; pragma Import (Ada, E208, "adacovex__parsers__tests_E");
   E211 : Short_Integer; pragma Import (Ada, E211, "adacovex__renderers__ansi_E");
   E224 : Short_Integer; pragma Import (Ada, E224, "adacovex__renderers__html_E");
   E213 : Short_Integer; pragma Import (Ada, E213, "adacovex__renderers__markdown_E");
   E219 : Short_Integer; pragma Import (Ada, E219, "adacovex__renderers__svg_E");
   E222 : Short_Integer; pragma Import (Ada, E222, "adacovex__server__http_E");

   Sec_Default_Sized_Stacks : array (1 .. 1) of aliased System.Secondary_Stack.SS_Stack (System.Parameters.Runtime_Default_Sec_Stack_Size);

   Local_Priority_Specific_Dispatching : constant String := "";
   Local_Interrupt_States : constant String := "";

   Is_Elaborated : Boolean := False;

   procedure finalize_library is
   begin
      declare
         procedure F1;
         pragma Import (Ada, F1, "ada__directories__finalize_body");
      begin
         E158 := E158 - 1;
         F1;
      end;
      declare
         procedure F2;
         pragma Import (Ada, F2, "ada__directories__finalize_spec");
      begin
         F2;
      end;
      E196 := E196 - 1;
      declare
         procedure F3;
         pragma Import (Ada, F3, "system__regexp__finalize_spec");
      begin
         F3;
      end;
      declare
         procedure F4;
         pragma Import (Ada, F4, "gnat__sockets__finalize_body");
      begin
         E227 := E227 - 1;
         F4;
      end;
      declare
         procedure F5;
         pragma Import (Ada, F5, "gnat__sockets__finalize_spec");
      begin
         F5;
      end;
      E246 := E246 - 1;
      declare
         procedure F6;
         pragma Import (Ada, F6, "system__pool_global__finalize_spec");
      begin
         F6;
      end;
      E119 := E119 - 1;
      declare
         procedure F7;
         pragma Import (Ada, F7, "ada__text_io__finalize_spec");
      begin
         F7;
      end;
      E185 := E185 - 1;
      declare
         procedure F8;
         pragma Import (Ada, F8, "ada__strings__unbounded__finalize_spec");
      begin
         F8;
      end;
      E250 := E250 - 1;
      declare
         procedure F9;
         pragma Import (Ada, F9, "system__storage_pools__subpools__finalize_spec");
      begin
         F9;
      end;
      declare
         procedure F10;
         pragma Import (Ada, F10, "system__file_io__finalize_body");
      begin
         E129 := E129 - 1;
         F10;
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

      Finalize_Library_Objects := finalize_library'access;

      Ada.Exceptions'Elab_Spec;
      System.Soft_Links'Elab_Spec;
      System.Exception_Table'Elab_Body;
      E022 := E022 + 1;
      Ada.Containers'Elab_Spec;
      E038 := E038 + 1;
      Ada.Io_Exceptions'Elab_Spec;
      E068 := E068 + 1;
      Ada.Numerics'Elab_Spec;
      E029 := E029 + 1;
      Ada.Strings'Elab_Spec;
      E053 := E053 + 1;
      Ada.Strings.Maps'Elab_Spec;
      E055 := E055 + 1;
      Ada.Strings.Maps.Constants'Elab_Spec;
      E058 := E058 + 1;
      Interfaces.C'Elab_Spec;
      E043 := E043 + 1;
      System.Exceptions'Elab_Spec;
      E023 := E023 + 1;
      System.Object_Reader'Elab_Spec;
      E084 := E084 + 1;
      System.Dwarf_Lines'Elab_Spec;
      E048 := E048 + 1;
      System.Os_Lib'Elab_Body;
      E073 := E073 + 1;
      System.Soft_Links.Initialize'Elab_Body;
      E018 := E018 + 1;
      E011 := E011 + 1;
      System.Traceback.Symbolic'Elab_Body;
      E037 := E037 + 1;
      E006 := E006 + 1;
      Ada.Assertions'Elab_Spec;
      E145 := E145 + 1;
      Ada.Strings.Utf_Encoding'Elab_Spec;
      E105 := E105 + 1;
      Ada.Tags'Elab_Spec;
      Ada.Tags'Elab_Body;
      E113 := E113 + 1;
      Ada.Strings.Text_Buffers'Elab_Spec;
      E103 := E103 + 1;
      Gnat'Elab_Spec;
      E225 := E225 + 1;
      Interfaces.C.Strings'Elab_Spec;
      E242 := E242 + 1;
      Ada.Streams'Elab_Spec;
      E121 := E121 + 1;
      System.File_Control_Block'Elab_Spec;
      E137 := E137 + 1;
      System.Finalization_Root'Elab_Spec;
      E132 := E132 + 1;
      Ada.Finalization'Elab_Spec;
      E130 := E130 + 1;
      System.File_Io'Elab_Body;
      E129 := E129 + 1;
      System.Storage_Pools'Elab_Spec;
      E198 := E198 + 1;
      System.Storage_Pools.Subpools'Elab_Spec;
      E250 := E250 + 1;
      Ada.Strings.Unbounded'Elab_Spec;
      E185 := E185 + 1;
      Ada.Calendar'Elab_Spec;
      Ada.Calendar'Elab_Body;
      E160 := E160 + 1;
      Ada.Calendar.Delays'Elab_Body;
      E234 := E234 + 1;
      Ada.Calendar.Time_Zones'Elab_Spec;
      E166 := E166 + 1;
      Ada.Text_Io'Elab_Spec;
      Ada.Text_Io'Elab_Body;
      E119 := E119 + 1;
      System.Pool_Global'Elab_Spec;
      E246 := E246 + 1;
      Gnat.Sockets'Elab_Spec;
      Gnat.Sockets.Thin_Common'Elab_Spec;
      E240 := E240 + 1;
      E232 := E232 + 1;
      Gnat.Sockets'Elab_Body;
      E227 := E227 + 1;
      E230 := E230 + 1;
      System.Regexp'Elab_Spec;
      E196 := E196 + 1;
      Ada.Directories'Elab_Spec;
      Ada.Directories'Elab_Body;
      E158 := E158 + 1;
      E154 := E154 + 1;
      E200 := E200 + 1;
      E152 := E152 + 1;
      E206 := E206 + 1;
      E156 := E156 + 1;
      E141 := E141 + 1;
      E208 := E208 + 1;
      E211 := E211 + 1;
      E224 := E224 + 1;
      E213 := E213 + 1;
      E219 := E219 + 1;
      E222 := E222 + 1;
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
   --   -lgnat
   --   -ldl
--  END Object file/option list   

end ada_main;
