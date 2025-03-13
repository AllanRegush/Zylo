include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Zylo_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Zylo_setup_options)
  option(Zylo_ENABLE_HARDENING "Enable hardening" ON)
  option(Zylo_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Zylo_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Zylo_ENABLE_HARDENING
    OFF)

  Zylo_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Zylo_PACKAGING_MAINTAINER_MODE)
    option(Zylo_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Zylo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Zylo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Zylo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Zylo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Zylo_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Zylo_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Zylo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Zylo_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Zylo_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Zylo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Zylo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Zylo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Zylo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Zylo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Zylo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Zylo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Zylo_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Zylo_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Zylo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Zylo_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Zylo_ENABLE_IPO
      Zylo_WARNINGS_AS_ERRORS
      Zylo_ENABLE_USER_LINKER
      Zylo_ENABLE_SANITIZER_ADDRESS
      Zylo_ENABLE_SANITIZER_LEAK
      Zylo_ENABLE_SANITIZER_UNDEFINED
      Zylo_ENABLE_SANITIZER_THREAD
      Zylo_ENABLE_SANITIZER_MEMORY
      Zylo_ENABLE_UNITY_BUILD
      Zylo_ENABLE_CLANG_TIDY
      Zylo_ENABLE_CPPCHECK
      Zylo_ENABLE_COVERAGE
      Zylo_ENABLE_PCH
      Zylo_ENABLE_CACHE)
  endif()

  Zylo_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Zylo_ENABLE_SANITIZER_ADDRESS OR Zylo_ENABLE_SANITIZER_THREAD OR Zylo_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Zylo_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Zylo_global_options)
  if(Zylo_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Zylo_enable_ipo()
  endif()

  Zylo_supports_sanitizers()

  if(Zylo_ENABLE_HARDENING AND Zylo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Zylo_ENABLE_SANITIZER_UNDEFINED
       OR Zylo_ENABLE_SANITIZER_ADDRESS
       OR Zylo_ENABLE_SANITIZER_THREAD
       OR Zylo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Zylo_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Zylo_ENABLE_SANITIZER_UNDEFINED}")
    Zylo_enable_hardening(Zylo_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Zylo_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Zylo_warnings INTERFACE)
  add_library(Zylo_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Zylo_set_project_warnings(
    Zylo_warnings
    ${Zylo_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Zylo_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    Zylo_configure_linker(Zylo_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Zylo_enable_sanitizers(
    Zylo_options
    ${Zylo_ENABLE_SANITIZER_ADDRESS}
    ${Zylo_ENABLE_SANITIZER_LEAK}
    ${Zylo_ENABLE_SANITIZER_UNDEFINED}
    ${Zylo_ENABLE_SANITIZER_THREAD}
    ${Zylo_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Zylo_options PROPERTIES UNITY_BUILD ${Zylo_ENABLE_UNITY_BUILD})

  if(Zylo_ENABLE_PCH)
    target_precompile_headers(
      Zylo_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Zylo_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Zylo_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Zylo_ENABLE_CLANG_TIDY)
    Zylo_enable_clang_tidy(Zylo_options ${Zylo_WARNINGS_AS_ERRORS})
  endif()

  if(Zylo_ENABLE_CPPCHECK)
    Zylo_enable_cppcheck(${Zylo_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Zylo_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Zylo_enable_coverage(Zylo_options)
  endif()

  if(Zylo_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Zylo_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Zylo_ENABLE_HARDENING AND NOT Zylo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Zylo_ENABLE_SANITIZER_UNDEFINED
       OR Zylo_ENABLE_SANITIZER_ADDRESS
       OR Zylo_ENABLE_SANITIZER_THREAD
       OR Zylo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Zylo_enable_hardening(Zylo_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
