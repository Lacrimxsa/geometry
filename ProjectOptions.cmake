include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(geometry_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(geometry_setup_options)
  option(geometry_ENABLE_HARDENING "Enable hardening" ON)
  option(geometry_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    geometry_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    geometry_ENABLE_HARDENING
    OFF)

  geometry_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR geometry_PACKAGING_MAINTAINER_MODE)
    option(geometry_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(geometry_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(geometry_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(geometry_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(geometry_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(geometry_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(geometry_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(geometry_ENABLE_PCH "Enable precompiled headers" OFF)
    option(geometry_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(geometry_ENABLE_IPO "Enable IPO/LTO" ON)
    option(geometry_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(geometry_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(geometry_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(geometry_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(geometry_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(geometry_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(geometry_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(geometry_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(geometry_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(geometry_ENABLE_PCH "Enable precompiled headers" OFF)
    option(geometry_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      geometry_ENABLE_IPO
      geometry_WARNINGS_AS_ERRORS
      geometry_ENABLE_USER_LINKER
      geometry_ENABLE_SANITIZER_ADDRESS
      geometry_ENABLE_SANITIZER_LEAK
      geometry_ENABLE_SANITIZER_UNDEFINED
      geometry_ENABLE_SANITIZER_THREAD
      geometry_ENABLE_SANITIZER_MEMORY
      geometry_ENABLE_UNITY_BUILD
      geometry_ENABLE_CLANG_TIDY
      geometry_ENABLE_CPPCHECK
      geometry_ENABLE_COVERAGE
      geometry_ENABLE_PCH
      geometry_ENABLE_CACHE)
  endif()

  geometry_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (geometry_ENABLE_SANITIZER_ADDRESS OR geometry_ENABLE_SANITIZER_THREAD OR geometry_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(geometry_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(geometry_global_options)
  if(geometry_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    geometry_enable_ipo()
  endif()

  geometry_supports_sanitizers()

  if(geometry_ENABLE_HARDENING AND geometry_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR geometry_ENABLE_SANITIZER_UNDEFINED
       OR geometry_ENABLE_SANITIZER_ADDRESS
       OR geometry_ENABLE_SANITIZER_THREAD
       OR geometry_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${geometry_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${geometry_ENABLE_SANITIZER_UNDEFINED}")
    geometry_enable_hardening(geometry_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(geometry_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(geometry_warnings INTERFACE)
  add_library(geometry_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  geometry_set_project_warnings(
    geometry_warnings
    ${geometry_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(geometry_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    geometry_configure_linker(geometry_options)
  endif()

  include(cmake/Sanitizers.cmake)
  geometry_enable_sanitizers(
    geometry_options
    ${geometry_ENABLE_SANITIZER_ADDRESS}
    ${geometry_ENABLE_SANITIZER_LEAK}
    ${geometry_ENABLE_SANITIZER_UNDEFINED}
    ${geometry_ENABLE_SANITIZER_THREAD}
    ${geometry_ENABLE_SANITIZER_MEMORY})

  set_target_properties(geometry_options PROPERTIES UNITY_BUILD ${geometry_ENABLE_UNITY_BUILD})

  if(geometry_ENABLE_PCH)
    target_precompile_headers(
      geometry_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(geometry_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    geometry_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(geometry_ENABLE_CLANG_TIDY)
    geometry_enable_clang_tidy(geometry_options ${geometry_WARNINGS_AS_ERRORS})
  endif()

  if(geometry_ENABLE_CPPCHECK)
    geometry_enable_cppcheck(${geometry_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(geometry_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    geometry_enable_coverage(geometry_options)
  endif()

  if(geometry_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(geometry_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(geometry_ENABLE_HARDENING AND NOT geometry_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR geometry_ENABLE_SANITIZER_UNDEFINED
       OR geometry_ENABLE_SANITIZER_ADDRESS
       OR geometry_ENABLE_SANITIZER_THREAD
       OR geometry_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    geometry_enable_hardening(geometry_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
