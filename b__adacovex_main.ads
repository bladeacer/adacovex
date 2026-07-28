pragma Warnings (Off);
pragma Ada_95;
with System;
with System.Parameters;
with System.Secondary_Stack;
package ada_main is

   gnat_argc : Integer;
   gnat_argv : System.Address;
   gnat_envp : System.Address;

   pragma Import (C, gnat_argc);
   pragma Import (C, gnat_argv);
   pragma Import (C, gnat_envp);

   gnat_exit_status : Integer;
   pragma Import (C, gnat_exit_status);

   GNAT_Version : constant String :=
                    "GNAT Version: 15.2.0" & ASCII.NUL;
   pragma Export (C, GNAT_Version, "__gnat_version");

   GNAT_Version_Address : constant System.Address := GNAT_Version'Address;
   pragma Export (C, GNAT_Version_Address, "__gnat_version_address");

   Ada_Main_Program_Name : constant String := "_ada_adacovex_main" & ASCII.NUL;
   pragma Export (C, Ada_Main_Program_Name, "__gnat_ada_main_program_name");

   procedure adainit;
   pragma Export (C, adainit, "adainit");

   procedure adafinal;
   pragma Export (C, adafinal, "adafinal");

   function main
     (argc : Integer;
      argv : System.Address;
      envp : System.Address)
      return Integer;
   pragma Export (C, main, "main");

   type Version_32 is mod 2 ** 32;
   u00001 : constant Version_32 := 16#a2388244#;
   pragma Export (C, u00001, "adacovex_mainB");
   u00002 : constant Version_32 := 16#b2cfab41#;
   pragma Export (C, u00002, "system__standard_libraryB");
   u00003 : constant Version_32 := 16#0626cc96#;
   pragma Export (C, u00003, "system__standard_libraryS");
   u00004 : constant Version_32 := 16#76789da1#;
   pragma Export (C, u00004, "adaS");
   u00005 : constant Version_32 := 16#57ff5296#;
   pragma Export (C, u00005, "ada__exceptionsB");
   u00006 : constant Version_32 := 16#64d9391c#;
   pragma Export (C, u00006, "ada__exceptionsS");
   u00007 : constant Version_32 := 16#85bf25f7#;
   pragma Export (C, u00007, "ada__exceptions__last_chance_handlerB");
   u00008 : constant Version_32 := 16#a028f72d#;
   pragma Export (C, u00008, "ada__exceptions__last_chance_handlerS");
   u00009 : constant Version_32 := 16#14286b0f#;
   pragma Export (C, u00009, "systemS");
   u00010 : constant Version_32 := 16#7fa0a598#;
   pragma Export (C, u00010, "system__soft_linksB");
   u00011 : constant Version_32 := 16#c7a3de26#;
   pragma Export (C, u00011, "system__soft_linksS");
   u00012 : constant Version_32 := 16#d0b087d0#;
   pragma Export (C, u00012, "system__secondary_stackB");
   u00013 : constant Version_32 := 16#bae33a03#;
   pragma Export (C, u00013, "system__secondary_stackS");
   u00014 : constant Version_32 := 16#a43efea2#;
   pragma Export (C, u00014, "system__parametersB");
   u00015 : constant Version_32 := 16#21bf971e#;
   pragma Export (C, u00015, "system__parametersS");
   u00016 : constant Version_32 := 16#d8f6bfe7#;
   pragma Export (C, u00016, "system__storage_elementsS");
   u00017 : constant Version_32 := 16#0286ce9f#;
   pragma Export (C, u00017, "system__soft_links__initializeB");
   u00018 : constant Version_32 := 16#ac2e8b53#;
   pragma Export (C, u00018, "system__soft_links__initializeS");
   u00019 : constant Version_32 := 16#8599b27b#;
   pragma Export (C, u00019, "system__stack_checkingB");
   u00020 : constant Version_32 := 16#d3777e19#;
   pragma Export (C, u00020, "system__stack_checkingS");
   u00021 : constant Version_32 := 16#45e1965e#;
   pragma Export (C, u00021, "system__exception_tableB");
   u00022 : constant Version_32 := 16#99031d16#;
   pragma Export (C, u00022, "system__exception_tableS");
   u00023 : constant Version_32 := 16#268dd43d#;
   pragma Export (C, u00023, "system__exceptionsS");
   u00024 : constant Version_32 := 16#c367aa24#;
   pragma Export (C, u00024, "system__exceptions__machineB");
   u00025 : constant Version_32 := 16#ec13924a#;
   pragma Export (C, u00025, "system__exceptions__machineS");
   u00026 : constant Version_32 := 16#7706238d#;
   pragma Export (C, u00026, "system__exceptions_debugB");
   u00027 : constant Version_32 := 16#2426335c#;
   pragma Export (C, u00027, "system__exceptions_debugS");
   u00028 : constant Version_32 := 16#36b7284e#;
   pragma Export (C, u00028, "system__img_intS");
   u00029 : constant Version_32 := 16#f2c63a02#;
   pragma Export (C, u00029, "ada__numericsS");
   u00030 : constant Version_32 := 16#174f5472#;
   pragma Export (C, u00030, "ada__numerics__big_numbersS");
   u00031 : constant Version_32 := 16#ee021456#;
   pragma Export (C, u00031, "system__unsigned_typesS");
   u00032 : constant Version_32 := 16#5c7d9c20#;
   pragma Export (C, u00032, "system__tracebackB");
   u00033 : constant Version_32 := 16#92b29fb2#;
   pragma Export (C, u00033, "system__tracebackS");
   u00034 : constant Version_32 := 16#5f6b6486#;
   pragma Export (C, u00034, "system__traceback_entriesB");
   u00035 : constant Version_32 := 16#dc34d483#;
   pragma Export (C, u00035, "system__traceback_entriesS");
   u00036 : constant Version_32 := 16#38e5c42b#;
   pragma Export (C, u00036, "system__traceback__symbolicB");
   u00037 : constant Version_32 := 16#140ceb78#;
   pragma Export (C, u00037, "system__traceback__symbolicS");
   u00038 : constant Version_32 := 16#179d7d28#;
   pragma Export (C, u00038, "ada__containersS");
   u00039 : constant Version_32 := 16#701f9d88#;
   pragma Export (C, u00039, "ada__exceptions__tracebackB");
   u00040 : constant Version_32 := 16#26ed0985#;
   pragma Export (C, u00040, "ada__exceptions__tracebackS");
   u00041 : constant Version_32 := 16#9111f9c1#;
   pragma Export (C, u00041, "interfacesS");
   u00042 : constant Version_32 := 16#401f6fd6#;
   pragma Export (C, u00042, "interfaces__cB");
   u00043 : constant Version_32 := 16#59e2f8b5#;
   pragma Export (C, u00043, "interfaces__cS");
   u00044 : constant Version_32 := 16#0978786d#;
   pragma Export (C, u00044, "system__bounded_stringsB");
   u00045 : constant Version_32 := 16#63d54a16#;
   pragma Export (C, u00045, "system__bounded_stringsS");
   u00046 : constant Version_32 := 16#9f0c0c80#;
   pragma Export (C, u00046, "system__crtlS");
   u00047 : constant Version_32 := 16#799f87ee#;
   pragma Export (C, u00047, "system__dwarf_linesB");
   u00048 : constant Version_32 := 16#6c65bf08#;
   pragma Export (C, u00048, "system__dwarf_linesS");
   u00049 : constant Version_32 := 16#5b4659fa#;
   pragma Export (C, u00049, "ada__charactersS");
   u00050 : constant Version_32 := 16#9de61c25#;
   pragma Export (C, u00050, "ada__characters__handlingB");
   u00051 : constant Version_32 := 16#729cc5db#;
   pragma Export (C, u00051, "ada__characters__handlingS");
   u00052 : constant Version_32 := 16#cde9ea2d#;
   pragma Export (C, u00052, "ada__characters__latin_1S");
   u00053 : constant Version_32 := 16#e6d4fa36#;
   pragma Export (C, u00053, "ada__stringsS");
   u00054 : constant Version_32 := 16#203d5282#;
   pragma Export (C, u00054, "ada__strings__mapsB");
   u00055 : constant Version_32 := 16#6feaa257#;
   pragma Export (C, u00055, "ada__strings__mapsS");
   u00056 : constant Version_32 := 16#b451a498#;
   pragma Export (C, u00056, "system__bit_opsB");
   u00057 : constant Version_32 := 16#d9dbc733#;
   pragma Export (C, u00057, "system__bit_opsS");
   u00058 : constant Version_32 := 16#b459efcb#;
   pragma Export (C, u00058, "ada__strings__maps__constantsS");
   u00059 : constant Version_32 := 16#f9910acc#;
   pragma Export (C, u00059, "system__address_imageB");
   u00060 : constant Version_32 := 16#b5c4f635#;
   pragma Export (C, u00060, "system__address_imageS");
   u00061 : constant Version_32 := 16#219681aa#;
   pragma Export (C, u00061, "system__img_address_32S");
   u00062 : constant Version_32 := 16#0cb62028#;
   pragma Export (C, u00062, "system__img_address_64S");
   u00063 : constant Version_32 := 16#7da15eb1#;
   pragma Export (C, u00063, "system__img_unsS");
   u00064 : constant Version_32 := 16#20ec7aa3#;
   pragma Export (C, u00064, "system__ioB");
   u00065 : constant Version_32 := 16#8a6a9c40#;
   pragma Export (C, u00065, "system__ioS");
   u00066 : constant Version_32 := 16#e15ca368#;
   pragma Export (C, u00066, "system__mmapB");
   u00067 : constant Version_32 := 16#99159588#;
   pragma Export (C, u00067, "system__mmapS");
   u00068 : constant Version_32 := 16#367911c4#;
   pragma Export (C, u00068, "ada__io_exceptionsS");
   u00069 : constant Version_32 := 16#a2858c95#;
   pragma Export (C, u00069, "system__mmap__os_interfaceB");
   u00070 : constant Version_32 := 16#48fa74ab#;
   pragma Export (C, u00070, "system__mmap__os_interfaceS");
   u00071 : constant Version_32 := 16#f4289573#;
   pragma Export (C, u00071, "system__mmap__unixS");
   u00072 : constant Version_32 := 16#c04dcb27#;
   pragma Export (C, u00072, "system__os_libB");
   u00073 : constant Version_32 := 16#9143f49f#;
   pragma Export (C, u00073, "system__os_libS");
   u00074 : constant Version_32 := 16#94d23d25#;
   pragma Export (C, u00074, "system__atomic_operations__test_and_setB");
   u00075 : constant Version_32 := 16#57acee8e#;
   pragma Export (C, u00075, "system__atomic_operations__test_and_setS");
   u00076 : constant Version_32 := 16#d34b112a#;
   pragma Export (C, u00076, "system__atomic_operationsS");
   u00077 : constant Version_32 := 16#553a519e#;
   pragma Export (C, u00077, "system__atomic_primitivesB");
   u00078 : constant Version_32 := 16#1cf8e0ec#;
   pragma Export (C, u00078, "system__atomic_primitivesS");
   u00079 : constant Version_32 := 16#b98923bf#;
   pragma Export (C, u00079, "system__case_utilB");
   u00080 : constant Version_32 := 16#db3bbc5a#;
   pragma Export (C, u00080, "system__case_utilS");
   u00081 : constant Version_32 := 16#256dbbe5#;
   pragma Export (C, u00081, "system__stringsB");
   u00082 : constant Version_32 := 16#8faa6b17#;
   pragma Export (C, u00082, "system__stringsS");
   u00083 : constant Version_32 := 16#836ccd31#;
   pragma Export (C, u00083, "system__object_readerB");
   u00084 : constant Version_32 := 16#18bcfe16#;
   pragma Export (C, u00084, "system__object_readerS");
   u00085 : constant Version_32 := 16#75406883#;
   pragma Export (C, u00085, "system__val_lliS");
   u00086 : constant Version_32 := 16#838eea00#;
   pragma Export (C, u00086, "system__val_lluS");
   u00087 : constant Version_32 := 16#47d9a892#;
   pragma Export (C, u00087, "system__sparkS");
   u00088 : constant Version_32 := 16#a571a4dc#;
   pragma Export (C, u00088, "system__spark__cut_operationsB");
   u00089 : constant Version_32 := 16#629c0fb7#;
   pragma Export (C, u00089, "system__spark__cut_operationsS");
   u00090 : constant Version_32 := 16#365e21c1#;
   pragma Export (C, u00090, "system__val_utilB");
   u00091 : constant Version_32 := 16#97ef3a91#;
   pragma Export (C, u00091, "system__val_utilS");
   u00092 : constant Version_32 := 16#382ef1e7#;
   pragma Export (C, u00092, "system__exception_tracesB");
   u00093 : constant Version_32 := 16#f8b00269#;
   pragma Export (C, u00093, "system__exception_tracesS");
   u00094 : constant Version_32 := 16#fd158a37#;
   pragma Export (C, u00094, "system__wch_conB");
   u00095 : constant Version_32 := 16#cd2b486c#;
   pragma Export (C, u00095, "system__wch_conS");
   u00096 : constant Version_32 := 16#5c289972#;
   pragma Export (C, u00096, "system__wch_stwB");
   u00097 : constant Version_32 := 16#e03a646d#;
   pragma Export (C, u00097, "system__wch_stwS");
   u00098 : constant Version_32 := 16#7cd63de5#;
   pragma Export (C, u00098, "system__wch_cnvB");
   u00099 : constant Version_32 := 16#cbeb821c#;
   pragma Export (C, u00099, "system__wch_cnvS");
   u00100 : constant Version_32 := 16#e538de43#;
   pragma Export (C, u00100, "system__wch_jisB");
   u00101 : constant Version_32 := 16#7e5ce036#;
   pragma Export (C, u00101, "system__wch_jisS");
   u00102 : constant Version_32 := 16#a201b8c5#;
   pragma Export (C, u00102, "ada__strings__text_buffersB");
   u00103 : constant Version_32 := 16#a7cfd09b#;
   pragma Export (C, u00103, "ada__strings__text_buffersS");
   u00104 : constant Version_32 := 16#8b7604c4#;
   pragma Export (C, u00104, "ada__strings__utf_encodingB");
   u00105 : constant Version_32 := 16#c9e86997#;
   pragma Export (C, u00105, "ada__strings__utf_encodingS");
   u00106 : constant Version_32 := 16#bb780f45#;
   pragma Export (C, u00106, "ada__strings__utf_encoding__stringsB");
   u00107 : constant Version_32 := 16#b85ff4b6#;
   pragma Export (C, u00107, "ada__strings__utf_encoding__stringsS");
   u00108 : constant Version_32 := 16#d1d1ed0b#;
   pragma Export (C, u00108, "ada__strings__utf_encoding__wide_stringsB");
   u00109 : constant Version_32 := 16#5678478f#;
   pragma Export (C, u00109, "ada__strings__utf_encoding__wide_stringsS");
   u00110 : constant Version_32 := 16#c2b98963#;
   pragma Export (C, u00110, "ada__strings__utf_encoding__wide_wide_stringsB");
   u00111 : constant Version_32 := 16#d7af3358#;
   pragma Export (C, u00111, "ada__strings__utf_encoding__wide_wide_stringsS");
   u00112 : constant Version_32 := 16#683e3bb7#;
   pragma Export (C, u00112, "ada__tagsB");
   u00113 : constant Version_32 := 16#4ff764f3#;
   pragma Export (C, u00113, "ada__tagsS");
   u00114 : constant Version_32 := 16#3548d972#;
   pragma Export (C, u00114, "system__htableB");
   u00115 : constant Version_32 := 16#95f133e4#;
   pragma Export (C, u00115, "system__htableS");
   u00116 : constant Version_32 := 16#1f1abe38#;
   pragma Export (C, u00116, "system__string_hashB");
   u00117 : constant Version_32 := 16#32b4b39b#;
   pragma Export (C, u00117, "system__string_hashS");
   u00118 : constant Version_32 := 16#27ac21ac#;
   pragma Export (C, u00118, "ada__text_ioB");
   u00119 : constant Version_32 := 16#04ab031f#;
   pragma Export (C, u00119, "ada__text_ioS");
   u00120 : constant Version_32 := 16#b228eb1e#;
   pragma Export (C, u00120, "ada__streamsB");
   u00121 : constant Version_32 := 16#613fe11c#;
   pragma Export (C, u00121, "ada__streamsS");
   u00122 : constant Version_32 := 16#05222263#;
   pragma Export (C, u00122, "system__put_imagesB");
   u00123 : constant Version_32 := 16#08866c10#;
   pragma Export (C, u00123, "system__put_imagesS");
   u00124 : constant Version_32 := 16#22b9eb9f#;
   pragma Export (C, u00124, "ada__strings__text_buffers__utilsB");
   u00125 : constant Version_32 := 16#89062ac3#;
   pragma Export (C, u00125, "ada__strings__text_buffers__utilsS");
   u00126 : constant Version_32 := 16#1cacf006#;
   pragma Export (C, u00126, "interfaces__c_streamsB");
   u00127 : constant Version_32 := 16#d07279c2#;
   pragma Export (C, u00127, "interfaces__c_streamsS");
   u00128 : constant Version_32 := 16#ec2f4d1e#;
   pragma Export (C, u00128, "system__file_ioB");
   u00129 : constant Version_32 := 16#72673e49#;
   pragma Export (C, u00129, "system__file_ioS");
   u00130 : constant Version_32 := 16#c34b231e#;
   pragma Export (C, u00130, "ada__finalizationS");
   u00131 : constant Version_32 := 16#d00f339c#;
   pragma Export (C, u00131, "system__finalization_rootB");
   u00132 : constant Version_32 := 16#1e5455db#;
   pragma Export (C, u00132, "system__finalization_rootS");
   u00133 : constant Version_32 := 16#ef3c5c6f#;
   pragma Export (C, u00133, "system__finalization_primitivesB");
   u00134 : constant Version_32 := 16#927c01c5#;
   pragma Export (C, u00134, "system__finalization_primitivesS");
   u00135 : constant Version_32 := 16#e8108c8c#;
   pragma Export (C, u00135, "system__os_locksS");
   u00136 : constant Version_32 := 16#fbeae7f4#;
   pragma Export (C, u00136, "system__os_constantsS");
   u00137 : constant Version_32 := 16#9e5df665#;
   pragma Export (C, u00137, "system__file_control_blockS");
   u00138 : constant Version_32 := 16#886beb6f#;
   pragma Export (C, u00138, "adacovexS");
   u00139 : constant Version_32 := 16#01e71279#;
   pragma Export (C, u00139, "adacovex__complianceS");
   u00140 : constant Version_32 := 16#a2fd68c9#;
   pragma Export (C, u00140, "adacovex__compliance__dalB");
   u00141 : constant Version_32 := 16#f9692903#;
   pragma Export (C, u00141, "adacovex__compliance__dalS");
   u00142 : constant Version_32 := 16#e259c480#;
   pragma Export (C, u00142, "system__assertionsB");
   u00143 : constant Version_32 := 16#322b1494#;
   pragma Export (C, u00143, "system__assertionsS");
   u00144 : constant Version_32 := 16#8b2c6428#;
   pragma Export (C, u00144, "ada__assertionsB");
   u00145 : constant Version_32 := 16#cc3ec2fd#;
   pragma Export (C, u00145, "ada__assertionsS");
   u00146 : constant Version_32 := 16#ca878138#;
   pragma Export (C, u00146, "system__concat_2B");
   u00147 : constant Version_32 := 16#a1d318f8#;
   pragma Export (C, u00147, "system__concat_2S");
   u00148 : constant Version_32 := 16#bcc987d2#;
   pragma Export (C, u00148, "system__concat_4B");
   u00149 : constant Version_32 := 16#27d03431#;
   pragma Export (C, u00149, "system__concat_4S");
   u00150 : constant Version_32 := 16#9d245557#;
   pragma Export (C, u00150, "adacovex__parsersS");
   u00151 : constant Version_32 := 16#d0f6dfb7#;
   pragma Export (C, u00151, "adacovex__parsers__do178cB");
   u00152 : constant Version_32 := 16#2e6a2922#;
   pragma Export (C, u00152, "adacovex__parsers__do178cS");
   u00153 : constant Version_32 := 16#0be4f98a#;
   pragma Export (C, u00153, "adacovex__typesB");
   u00154 : constant Version_32 := 16#3d89f7aa#;
   pragma Export (C, u00154, "adacovex__typesS");
   u00155 : constant Version_32 := 16#57f1cbf9#;
   pragma Export (C, u00155, "adacovex__parsers__sourceB");
   u00156 : constant Version_32 := 16#60fd7112#;
   pragma Export (C, u00156, "adacovex__parsers__sourceS");
   u00157 : constant Version_32 := 16#85b92d20#;
   pragma Export (C, u00157, "ada__directoriesB");
   u00158 : constant Version_32 := 16#c1305a6c#;
   pragma Export (C, u00158, "ada__directoriesS");
   u00159 : constant Version_32 := 16#78511131#;
   pragma Export (C, u00159, "ada__calendarB");
   u00160 : constant Version_32 := 16#c907a168#;
   pragma Export (C, u00160, "ada__calendarS");
   u00161 : constant Version_32 := 16#d172d809#;
   pragma Export (C, u00161, "system__os_primitivesB");
   u00162 : constant Version_32 := 16#13d50ef9#;
   pragma Export (C, u00162, "system__os_primitivesS");
   u00163 : constant Version_32 := 16#c1ef1512#;
   pragma Export (C, u00163, "ada__calendar__formattingB");
   u00164 : constant Version_32 := 16#5a9d5c4e#;
   pragma Export (C, u00164, "ada__calendar__formattingS");
   u00165 : constant Version_32 := 16#974d849e#;
   pragma Export (C, u00165, "ada__calendar__time_zonesB");
   u00166 : constant Version_32 := 16#55da5b9f#;
   pragma Export (C, u00166, "ada__calendar__time_zonesS");
   u00167 : constant Version_32 := 16#0a4a0a25#;
   pragma Export (C, u00167, "system__val_fixed_64S");
   u00168 : constant Version_32 := 16#afdc38b2#;
   pragma Export (C, u00168, "system__arith_64B");
   u00169 : constant Version_32 := 16#509fabdd#;
   pragma Export (C, u00169, "system__arith_64S");
   u00170 : constant Version_32 := 16#aa0160a2#;
   pragma Export (C, u00170, "system__val_intS");
   u00171 : constant Version_32 := 16#5da6ebca#;
   pragma Export (C, u00171, "system__val_unsS");
   u00172 : constant Version_32 := 16#c3b32edd#;
   pragma Export (C, u00172, "ada__containers__helpersB");
   u00173 : constant Version_32 := 16#444c93c2#;
   pragma Export (C, u00173, "ada__containers__helpersS");
   u00174 : constant Version_32 := 16#52627794#;
   pragma Export (C, u00174, "system__atomic_countersB");
   u00175 : constant Version_32 := 16#c83084cc#;
   pragma Export (C, u00175, "system__atomic_countersS");
   u00176 : constant Version_32 := 16#1dec9118#;
   pragma Export (C, u00176, "ada__directories__hierarchical_file_namesB");
   u00177 : constant Version_32 := 16#34d5eeb2#;
   pragma Export (C, u00177, "ada__directories__hierarchical_file_namesS");
   u00178 : constant Version_32 := 16#ab4ad33a#;
   pragma Export (C, u00178, "ada__directories__validityB");
   u00179 : constant Version_32 := 16#0877bcae#;
   pragma Export (C, u00179, "ada__directories__validityS");
   u00180 : constant Version_32 := 16#96a20755#;
   pragma Export (C, u00180, "ada__strings__fixedB");
   u00181 : constant Version_32 := 16#11b694ce#;
   pragma Export (C, u00181, "ada__strings__fixedS");
   u00182 : constant Version_32 := 16#b40d9bf2#;
   pragma Export (C, u00182, "ada__strings__searchB");
   u00183 : constant Version_32 := 16#97fe4a15#;
   pragma Export (C, u00183, "ada__strings__searchS");
   u00184 : constant Version_32 := 16#4259a79c#;
   pragma Export (C, u00184, "ada__strings__unboundedB");
   u00185 : constant Version_32 := 16#b40332b4#;
   pragma Export (C, u00185, "ada__strings__unboundedS");
   u00186 : constant Version_32 := 16#d79db92c#;
   pragma Export (C, u00186, "system__return_stackS");
   u00187 : constant Version_32 := 16#756a1fdd#;
   pragma Export (C, u00187, "system__stream_attributesB");
   u00188 : constant Version_32 := 16#a8236f45#;
   pragma Export (C, u00188, "system__stream_attributesS");
   u00189 : constant Version_32 := 16#1c617d0b#;
   pragma Export (C, u00189, "system__stream_attributes__xdrB");
   u00190 : constant Version_32 := 16#e4218e58#;
   pragma Export (C, u00190, "system__stream_attributes__xdrS");
   u00191 : constant Version_32 := 16#d71ab463#;
   pragma Export (C, u00191, "system__fat_fltS");
   u00192 : constant Version_32 := 16#f128bd6e#;
   pragma Export (C, u00192, "system__fat_lfltS");
   u00193 : constant Version_32 := 16#8bf81384#;
   pragma Export (C, u00193, "system__fat_llfS");
   u00194 : constant Version_32 := 16#aaf681ed#;
   pragma Export (C, u00194, "system__file_attributesS");
   u00195 : constant Version_32 := 16#8f8e85c2#;
   pragma Export (C, u00195, "system__regexpB");
   u00196 : constant Version_32 := 16#371accc3#;
   pragma Export (C, u00196, "system__regexpS");
   u00197 : constant Version_32 := 16#35d6ef80#;
   pragma Export (C, u00197, "system__storage_poolsB");
   u00198 : constant Version_32 := 16#8e431254#;
   pragma Export (C, u00198, "system__storage_poolsS");
   u00199 : constant Version_32 := 16#e57d0adc#;
   pragma Export (C, u00199, "adacovex__configB");
   u00200 : constant Version_32 := 16#b51f6130#;
   pragma Export (C, u00200, "adacovex__configS");
   u00201 : constant Version_32 := 16#fe7a0f2d#;
   pragma Export (C, u00201, "ada__command_lineB");
   u00202 : constant Version_32 := 16#3cdef8c9#;
   pragma Export (C, u00202, "ada__command_lineS");
   u00203 : constant Version_32 := 16#752a67ed#;
   pragma Export (C, u00203, "system__concat_3B");
   u00204 : constant Version_32 := 16#9e5272ad#;
   pragma Export (C, u00204, "system__concat_3S");
   u00205 : constant Version_32 := 16#ae210ed4#;
   pragma Export (C, u00205, "adacovex__parsers__gnatproveB");
   u00206 : constant Version_32 := 16#d65ff4b5#;
   pragma Export (C, u00206, "adacovex__parsers__gnatproveS");
   u00207 : constant Version_32 := 16#d979eb23#;
   pragma Export (C, u00207, "adacovex__parsers__testsB");
   u00208 : constant Version_32 := 16#085c8fcb#;
   pragma Export (C, u00208, "adacovex__parsers__testsS");
   u00209 : constant Version_32 := 16#f7b37384#;
   pragma Export (C, u00209, "adacovex__renderersS");
   u00210 : constant Version_32 := 16#1eecd448#;
   pragma Export (C, u00210, "adacovex__renderers__ansiB");
   u00211 : constant Version_32 := 16#50941dbd#;
   pragma Export (C, u00211, "adacovex__renderers__ansiS");
   u00212 : constant Version_32 := 16#0c1736dc#;
   pragma Export (C, u00212, "adacovex__renderers__markdownB");
   u00213 : constant Version_32 := 16#323123f7#;
   pragma Export (C, u00213, "adacovex__renderers__markdownS");
   u00214 : constant Version_32 := 16#ebb39bbb#;
   pragma Export (C, u00214, "system__concat_5B");
   u00215 : constant Version_32 := 16#54b1bad4#;
   pragma Export (C, u00215, "system__concat_5S");
   u00216 : constant Version_32 := 16#ada38524#;
   pragma Export (C, u00216, "system__concat_7B");
   u00217 : constant Version_32 := 16#1dd52a90#;
   pragma Export (C, u00217, "system__concat_7S");
   u00218 : constant Version_32 := 16#bc673318#;
   pragma Export (C, u00218, "adacovex__renderers__svgB");
   u00219 : constant Version_32 := 16#02588900#;
   pragma Export (C, u00219, "adacovex__renderers__svgS");
   u00220 : constant Version_32 := 16#4659b09e#;
   pragma Export (C, u00220, "adacovex__serverS");
   u00221 : constant Version_32 := 16#ab476a8a#;
   pragma Export (C, u00221, "adacovex__server__httpB");
   u00222 : constant Version_32 := 16#feebfc72#;
   pragma Export (C, u00222, "adacovex__server__httpS");
   u00223 : constant Version_32 := 16#df7f3e17#;
   pragma Export (C, u00223, "adacovex__renderers__htmlB");
   u00224 : constant Version_32 := 16#653639c8#;
   pragma Export (C, u00224, "adacovex__renderers__htmlS");
   u00225 : constant Version_32 := 16#b5988c27#;
   pragma Export (C, u00225, "gnatS");
   u00226 : constant Version_32 := 16#3efcd9f0#;
   pragma Export (C, u00226, "gnat__socketsB");
   u00227 : constant Version_32 := 16#7eb370b7#;
   pragma Export (C, u00227, "gnat__socketsS");
   u00228 : constant Version_32 := 16#17f10572#;
   pragma Export (C, u00228, "gnat__sockets__linker_optionsS");
   u00229 : constant Version_32 := 16#f4865ffd#;
   pragma Export (C, u00229, "gnat__sockets__pollB");
   u00230 : constant Version_32 := 16#0c75e0c2#;
   pragma Export (C, u00230, "gnat__sockets__pollS");
   u00231 : constant Version_32 := 16#fc832f5d#;
   pragma Export (C, u00231, "gnat__sockets__thinB");
   u00232 : constant Version_32 := 16#37c305b6#;
   pragma Export (C, u00232, "gnat__sockets__thinS");
   u00233 : constant Version_32 := 16#0513e9ec#;
   pragma Export (C, u00233, "ada__calendar__delaysB");
   u00234 : constant Version_32 := 16#205f84f4#;
   pragma Export (C, u00234, "ada__calendar__delaysS");
   u00235 : constant Version_32 := 16#656efae9#;
   pragma Export (C, u00235, "gnat__os_libS");
   u00236 : constant Version_32 := 16#485b8267#;
   pragma Export (C, u00236, "gnat__task_lockS");
   u00237 : constant Version_32 := 16#ff7f7d40#;
   pragma Export (C, u00237, "system__task_lockB");
   u00238 : constant Version_32 := 16#75a25c61#;
   pragma Export (C, u00238, "system__task_lockS");
   u00239 : constant Version_32 := 16#a02b8996#;
   pragma Export (C, u00239, "gnat__sockets__thin_commonB");
   u00240 : constant Version_32 := 16#c4885490#;
   pragma Export (C, u00240, "gnat__sockets__thin_commonS");
   u00241 : constant Version_32 := 16#58c21abc#;
   pragma Export (C, u00241, "interfaces__c__stringsB");
   u00242 : constant Version_32 := 16#bd4557ce#;
   pragma Export (C, u00242, "interfaces__c__stringsS");
   u00243 : constant Version_32 := 16#5de653db#;
   pragma Export (C, u00243, "system__communicationB");
   u00244 : constant Version_32 := 16#bb9c8d3c#;
   pragma Export (C, u00244, "system__communicationS");
   u00245 : constant Version_32 := 16#ae5b86de#;
   pragma Export (C, u00245, "system__pool_globalB");
   u00246 : constant Version_32 := 16#a07c1f1e#;
   pragma Export (C, u00246, "system__pool_globalS");
   u00247 : constant Version_32 := 16#0ddbd91f#;
   pragma Export (C, u00247, "system__memoryB");
   u00248 : constant Version_32 := 16#0cbcf715#;
   pragma Export (C, u00248, "system__memoryS");
   u00249 : constant Version_32 := 16#690693e0#;
   pragma Export (C, u00249, "system__storage_pools__subpoolsB");
   u00250 : constant Version_32 := 16#23a252fc#;
   pragma Export (C, u00250, "system__storage_pools__subpoolsS");
   u00251 : constant Version_32 := 16#3676fd0b#;
   pragma Export (C, u00251, "system__storage_pools__subpools__finalizationB");
   u00252 : constant Version_32 := 16#54c94065#;
   pragma Export (C, u00252, "system__storage_pools__subpools__finalizationS");

   --  BEGIN ELABORATION ORDER
   --  ada%s
   --  ada.characters%s
   --  ada.characters.latin_1%s
   --  interfaces%s
   --  system%s
   --  system.atomic_operations%s
   --  system.io%s
   --  system.io%b
   --  system.parameters%s
   --  system.parameters%b
   --  system.crtl%s
   --  interfaces.c_streams%s
   --  interfaces.c_streams%b
   --  system.os_primitives%s
   --  system.os_primitives%b
   --  system.spark%s
   --  system.spark.cut_operations%s
   --  system.spark.cut_operations%b
   --  system.storage_elements%s
   --  system.img_address_32%s
   --  system.img_address_64%s
   --  system.return_stack%s
   --  system.stack_checking%s
   --  system.stack_checking%b
   --  system.string_hash%s
   --  system.string_hash%b
   --  system.htable%s
   --  system.htable%b
   --  system.strings%s
   --  system.strings%b
   --  system.traceback_entries%s
   --  system.traceback_entries%b
   --  system.unsigned_types%s
   --  system.wch_con%s
   --  system.wch_con%b
   --  system.wch_jis%s
   --  system.wch_jis%b
   --  system.wch_cnv%s
   --  system.wch_cnv%b
   --  system.concat_2%s
   --  system.concat_2%b
   --  system.concat_3%s
   --  system.concat_3%b
   --  system.concat_4%s
   --  system.concat_4%b
   --  system.concat_5%s
   --  system.concat_5%b
   --  system.concat_7%s
   --  system.concat_7%b
   --  system.traceback%s
   --  system.traceback%b
   --  ada.characters.handling%s
   --  system.atomic_operations.test_and_set%s
   --  system.case_util%s
   --  system.os_lib%s
   --  system.secondary_stack%s
   --  system.standard_library%s
   --  ada.exceptions%s
   --  system.exceptions_debug%s
   --  system.exceptions_debug%b
   --  system.soft_links%s
   --  system.val_util%s
   --  system.val_util%b
   --  system.val_llu%s
   --  system.val_lli%s
   --  system.wch_stw%s
   --  system.wch_stw%b
   --  ada.exceptions.last_chance_handler%s
   --  ada.exceptions.last_chance_handler%b
   --  ada.exceptions.traceback%s
   --  ada.exceptions.traceback%b
   --  system.address_image%s
   --  system.address_image%b
   --  system.bit_ops%s
   --  system.bit_ops%b
   --  system.bounded_strings%s
   --  system.bounded_strings%b
   --  system.case_util%b
   --  system.exception_table%s
   --  system.exception_table%b
   --  ada.containers%s
   --  ada.io_exceptions%s
   --  ada.numerics%s
   --  ada.numerics.big_numbers%s
   --  ada.strings%s
   --  ada.strings.maps%s
   --  ada.strings.maps%b
   --  ada.strings.maps.constants%s
   --  interfaces.c%s
   --  interfaces.c%b
   --  system.atomic_primitives%s
   --  system.atomic_primitives%b
   --  system.exceptions%s
   --  system.exceptions.machine%s
   --  system.exceptions.machine%b
   --  ada.characters.handling%b
   --  system.atomic_operations.test_and_set%b
   --  system.exception_traces%s
   --  system.exception_traces%b
   --  system.img_int%s
   --  system.img_uns%s
   --  system.memory%s
   --  system.memory%b
   --  system.mmap%s
   --  system.mmap.os_interface%s
   --  system.mmap%b
   --  system.mmap.unix%s
   --  system.mmap.os_interface%b
   --  system.object_reader%s
   --  system.object_reader%b
   --  system.dwarf_lines%s
   --  system.dwarf_lines%b
   --  system.os_lib%b
   --  system.secondary_stack%b
   --  system.soft_links.initialize%s
   --  system.soft_links.initialize%b
   --  system.soft_links%b
   --  system.standard_library%b
   --  system.traceback.symbolic%s
   --  system.traceback.symbolic%b
   --  ada.exceptions%b
   --  ada.assertions%s
   --  ada.assertions%b
   --  ada.command_line%s
   --  ada.command_line%b
   --  ada.strings.search%s
   --  ada.strings.search%b
   --  ada.strings.fixed%s
   --  ada.strings.fixed%b
   --  ada.strings.utf_encoding%s
   --  ada.strings.utf_encoding%b
   --  ada.strings.utf_encoding.strings%s
   --  ada.strings.utf_encoding.strings%b
   --  ada.strings.utf_encoding.wide_strings%s
   --  ada.strings.utf_encoding.wide_strings%b
   --  ada.strings.utf_encoding.wide_wide_strings%s
   --  ada.strings.utf_encoding.wide_wide_strings%b
   --  ada.tags%s
   --  ada.tags%b
   --  ada.strings.text_buffers%s
   --  ada.strings.text_buffers%b
   --  ada.strings.text_buffers.utils%s
   --  ada.strings.text_buffers.utils%b
   --  gnat%s
   --  gnat.os_lib%s
   --  interfaces.c.strings%s
   --  interfaces.c.strings%b
   --  system.arith_64%s
   --  system.arith_64%b
   --  system.atomic_counters%s
   --  system.atomic_counters%b
   --  system.fat_flt%s
   --  system.fat_lflt%s
   --  system.fat_llf%s
   --  system.os_constants%s
   --  system.os_locks%s
   --  system.finalization_primitives%s
   --  system.finalization_primitives%b
   --  system.put_images%s
   --  system.put_images%b
   --  ada.streams%s
   --  ada.streams%b
   --  system.communication%s
   --  system.communication%b
   --  system.file_control_block%s
   --  system.finalization_root%s
   --  system.finalization_root%b
   --  ada.finalization%s
   --  ada.containers.helpers%s
   --  ada.containers.helpers%b
   --  system.file_io%s
   --  system.file_io%b
   --  system.storage_pools%s
   --  system.storage_pools%b
   --  system.storage_pools.subpools%s
   --  system.storage_pools.subpools.finalization%s
   --  system.storage_pools.subpools.finalization%b
   --  system.storage_pools.subpools%b
   --  system.stream_attributes%s
   --  system.stream_attributes.xdr%s
   --  system.stream_attributes.xdr%b
   --  system.stream_attributes%b
   --  ada.strings.unbounded%s
   --  ada.strings.unbounded%b
   --  system.task_lock%s
   --  system.task_lock%b
   --  gnat.task_lock%s
   --  system.val_fixed_64%s
   --  system.val_uns%s
   --  system.val_int%s
   --  ada.calendar%s
   --  ada.calendar%b
   --  ada.calendar.delays%s
   --  ada.calendar.delays%b
   --  ada.calendar.time_zones%s
   --  ada.calendar.time_zones%b
   --  ada.calendar.formatting%s
   --  ada.calendar.formatting%b
   --  ada.text_io%s
   --  ada.text_io%b
   --  system.assertions%s
   --  system.assertions%b
   --  system.file_attributes%s
   --  system.pool_global%s
   --  system.pool_global%b
   --  gnat.sockets%s
   --  gnat.sockets.linker_options%s
   --  gnat.sockets.poll%s
   --  gnat.sockets.thin_common%s
   --  gnat.sockets.thin_common%b
   --  gnat.sockets.thin%s
   --  gnat.sockets.thin%b
   --  gnat.sockets%b
   --  gnat.sockets.poll%b
   --  system.regexp%s
   --  system.regexp%b
   --  ada.directories%s
   --  ada.directories.hierarchical_file_names%s
   --  ada.directories.validity%s
   --  ada.directories.validity%b
   --  ada.directories%b
   --  ada.directories.hierarchical_file_names%b
   --  adacovex%s
   --  adacovex.compliance%s
   --  adacovex.parsers%s
   --  adacovex.renderers%s
   --  adacovex.server%s
   --  adacovex.types%s
   --  adacovex.types%b
   --  adacovex.config%s
   --  adacovex.config%b
   --  adacovex.parsers.do178c%s
   --  adacovex.parsers.do178c%b
   --  adacovex.parsers.gnatprove%s
   --  adacovex.parsers.gnatprove%b
   --  adacovex.parsers.source%s
   --  adacovex.parsers.source%b
   --  adacovex.compliance.dal%s
   --  adacovex.compliance.dal%b
   --  adacovex.parsers.tests%s
   --  adacovex.parsers.tests%b
   --  adacovex.renderers.ansi%s
   --  adacovex.renderers.ansi%b
   --  adacovex.renderers.html%s
   --  adacovex.renderers.html%b
   --  adacovex.renderers.markdown%s
   --  adacovex.renderers.markdown%b
   --  adacovex.renderers.svg%s
   --  adacovex.renderers.svg%b
   --  adacovex.server.http%s
   --  adacovex.server.http%b
   --  adacovex_main%b
   --  END ELABORATION ORDER

end ada_main;
