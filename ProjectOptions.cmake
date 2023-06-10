include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(tinyChat_supports_sanitizers)
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

macro(tinyChat_setup_options)
  option(tinyChat_ENABLE_HARDENING "Enable hardening" ON)
  option(tinyChat_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    tinyChat_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    tinyChat_ENABLE_HARDENING
    OFF)

  tinyChat_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR tinyChat_PACKAGING_MAINTAINER_MODE)
    option(tinyChat_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(tinyChat_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(tinyChat_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tinyChat_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tinyChat_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tinyChat_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(tinyChat_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(tinyChat_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tinyChat_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(tinyChat_ENABLE_IPO "Enable IPO/LTO" ON)
    option(tinyChat_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(tinyChat_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tinyChat_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(tinyChat_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(tinyChat_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tinyChat_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tinyChat_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tinyChat_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(tinyChat_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(tinyChat_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tinyChat_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      tinyChat_ENABLE_IPO
      tinyChat_WARNINGS_AS_ERRORS
      tinyChat_ENABLE_USER_LINKER
      tinyChat_ENABLE_SANITIZER_ADDRESS
      tinyChat_ENABLE_SANITIZER_LEAK
      tinyChat_ENABLE_SANITIZER_UNDEFINED
      tinyChat_ENABLE_SANITIZER_THREAD
      tinyChat_ENABLE_SANITIZER_MEMORY
      tinyChat_ENABLE_UNITY_BUILD
      tinyChat_ENABLE_CLANG_TIDY
      tinyChat_ENABLE_CPPCHECK
      tinyChat_ENABLE_COVERAGE
      tinyChat_ENABLE_PCH
      tinyChat_ENABLE_CACHE)
  endif()

  tinyChat_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (tinyChat_ENABLE_SANITIZER_ADDRESS OR tinyChat_ENABLE_SANITIZER_THREAD OR tinyChat_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(tinyChat_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(tinyChat_global_options)
  if(tinyChat_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    tinyChat_enable_ipo()
  endif()

  tinyChat_supports_sanitizers()

  if(tinyChat_ENABLE_HARDENING AND tinyChat_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tinyChat_ENABLE_SANITIZER_UNDEFINED
       OR tinyChat_ENABLE_SANITIZER_ADDRESS
       OR tinyChat_ENABLE_SANITIZER_THREAD
       OR tinyChat_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${tinyChat_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${tinyChat_ENABLE_SANITIZER_UNDEFINED}")
    tinyChat_enable_hardening(tinyChat_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(tinyChat_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(tinyChat_warnings INTERFACE)
  add_library(tinyChat_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  tinyChat_set_project_warnings(
    tinyChat_warnings
    ${tinyChat_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(tinyChat_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(tinyChat_options)
  endif()

  include(cmake/Sanitizers.cmake)
  tinyChat_enable_sanitizers(
    tinyChat_options
    ${tinyChat_ENABLE_SANITIZER_ADDRESS}
    ${tinyChat_ENABLE_SANITIZER_LEAK}
    ${tinyChat_ENABLE_SANITIZER_UNDEFINED}
    ${tinyChat_ENABLE_SANITIZER_THREAD}
    ${tinyChat_ENABLE_SANITIZER_MEMORY})

  set_target_properties(tinyChat_options PROPERTIES UNITY_BUILD ${tinyChat_ENABLE_UNITY_BUILD})

  if(tinyChat_ENABLE_PCH)
    target_precompile_headers(
      tinyChat_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(tinyChat_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    tinyChat_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(tinyChat_ENABLE_CLANG_TIDY)
    tinyChat_enable_clang_tidy(tinyChat_options ${tinyChat_WARNINGS_AS_ERRORS})
  endif()

  if(tinyChat_ENABLE_CPPCHECK)
    tinyChat_enable_cppcheck(${tinyChat_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(tinyChat_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    tinyChat_enable_coverage(tinyChat_options)
  endif()

  if(tinyChat_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(tinyChat_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(tinyChat_ENABLE_HARDENING AND NOT tinyChat_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tinyChat_ENABLE_SANITIZER_UNDEFINED
       OR tinyChat_ENABLE_SANITIZER_ADDRESS
       OR tinyChat_ENABLE_SANITIZER_THREAD
       OR tinyChat_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    tinyChat_enable_hardening(tinyChat_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
