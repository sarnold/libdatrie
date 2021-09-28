cmake_minimum_required(VERSION 3.10...3.18)

# Add cmake modules of this project to the module path
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

# used for both library and pkgconfig file
# Library versioning
# Library code modified:                    REVISION++
# Interfaces added:              CURRENT++  REVISION=0  AGE++
# Interfaces changed/removed:    CURRENT++  REVISION=0  AGE=0
#
# as of package version 0.2.13; note not all of the ABI bits are
# used for building/packaging shared libs, and the (package) VERSION
# is expected to be defined for trietool:
# LT_CURRENT=5
# LT_REVISION=0
# LT_AGE=4

set(VERSION 0.2.13)  # this is used for config.h and included by trietool
set(LIBRARY_ABI_REV 4.0)
set(LIBRARY_ABI_VERSION "5.${LIBRARY_ABI_REV}")  # not used here
set(LIBRARY_SOVERSION 1)
set(LIBRARY_FULL_VERSION "${LIBRARY_SOVERSION}.${LIBRARY_ABI_REV}")

if(POLICY CMP0048)
  cmake_policy(SET CMP0048 NEW)
endif()

project(libdatrie LANGUAGES C CXX VERSION ${VERSION})

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_VERBOSE_MAKEFILE ON)

set(CMAKE_C_STANDARD 99)
set(CMAKE_DEBUG_POSTFIX d)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING
    "Default build type: RelWithDebInfo" FORCE)
endif()

# Ensure proper configuration if in a conda environment
#include(CondaAware)

option(BUILD_SHARED_LIBS "build shared libraries" ON)
option(BUILD_STATIC_LIBS "Build static libraries" OFF)
option(SKIP_TOOL "Skip trietool" OFF)

option(LIBDATRIE_BUILD_TESTING "build and run tests" ON)

set(WITH_COVERAGE "" CACHE PATH "build with test coverage enabled")

set(LIBDATRIE_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR})
set(INCLUDE_DIRS ${LIBDATRIE_INCLUDE_DIRS}
  ${CMAKE_CURRENT_BINARY_DIR})

include_directories(${INCLUDE_DIRS})

set(INSTALL_PKGCONFIG_DIR
  "${CMAKE_INSTALL_PREFIX}/share/pkgconfig"
  CACHE PATH "Install directory for pkgconfig (.pc) files")

set(EXTRA_TARGET_LINK_LIBRARIES)

include(CTest)
include(GNUInstallDirs)
include(CheckIncludeFile)
include(CheckFunctionExists)

# start CONFIG_H checks
set(STDC_HEADERS 1)
check_include_file(inttypes.h HAVE_INTTYPES_H)
check_include_file(limits.h HAVE_LIMITS_H)
check_include_file(memory.h HAVE_MEMORY_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stdio.h HAVE_STDIO_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(sys/stat.h HAVE_SYS_STAT_H)
check_include_file(sys/types.h HAVE_SYS_TYPES_H)

check_function_exists(nl_langinfo HAVE_LANGINFO_CODESET)
check_function_exists(locale_charset HAVE_LOCALE_CHARSET)
check_function_exists(malloc HAVE_MALLOC)

if(WITH_COVERAGE)
    add_compile_options(--coverage)
    add_link_options(--coverage)
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
  if(MSVC_VERSION LESS 1900)
    message(FATAL_ERROR "you need Visual Studio 2015 or later")
  endif()
  if(BUILD_SHARED_LIBS)
    # See http://www.kitware.com/blog/home/post/939 for details.
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
  endif()
  # CMake defaults to /W3, but some users like /W4 (or /Wall) and /WX,
  # so we disable various warnings that aren't particularly helpful.
  add_compile_options(/wd4100 /wd4201 /wd4456 /wd4457 /wd4702 /wd4815)
  # Without a byte order mark (BOM), Visual Studio assumes that the source
  # file is encoded using the current user code page, so we specify UTF-8.
  add_compile_options(/utf-8)
endif()

if(WIN32)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_DEPRECATE)
  add_compile_definitions(WIN32_LEAN_AND_MEAN UNICODE _UNICODE STRICT NOMINMAX)
endif()

set(LIBDATRIE_SOURCES
    datrie/alpha-map.c
    datrie/darray.c
    datrie/dstring.c
    datrie/fileutils.c
    datrie/tail.c
    datrie/trie.c
    datrie/trie-string.c
)

set(LIBDATRIE_HEADERS
    datrie/alpha-map.h
    datrie/trie.h
    datrie/triedefs.h
    datrie/typedefs.h
)

#if(WIN32)
    #list(APPEND LIBDATRIE_SOURCES datrie/libdatrie.def)
#endif()

if(BUILD_STATIC_LIBS)
  add_library(datriestatic STATIC ${LIBDATRIE_SOURCES})
  set_target_properties(datriestatic PROPERTIES OUTPUT_NAME datrie)
endif()

if(BUILD_SHARED_LIBS)
  add_library(datrie SHARED ${LIBDATRIE_SOURCES})
  add_library(Datrie::Datrie ALIAS datrie)
endif()

set_target_properties(datrie
  PROPERTIES
  VERSION ${LIBRARY_FULL_VERSION}
  SOVERSION ${LIBRARY_SOVERSION}
  )

if(LIBDATRIE_BUILD_TESTING)
  set(TESTING_SOURCES
    tests/utils.h
    tests/utils.c
    )

  add_library(testing STATIC ${TESTING_SOURCES})

  set(TEST_TARGETS
    test_byte_alpha
    test_byte_list
    test_file
    test_iterator
    test_nonalpha
    test_null_trie
    test_serialization
    test_store-retrieve
    test_term_state
    test_walk
    )

  foreach(target ${TEST_TARGETS})
    add_executable(${target} tests/${target}.c)
    target_link_libraries(${target}
      testing
      datrie
      )

    add_test(NAME ${target} COMMAND ${target})
  endforeach(target)
endif()

if(NOT SKIP_TOOL)
  if(UNIX)
    find_path(ICONV_INCLUDE_DIR iconv.h)
    if(ICONV_INCLUDE_DIR)
      include_directories(${ICONV_INCLUDE_DIR})
    endif()

    if(APPLE)
      find_library(ICONV_LIB NAMES iconv libiconv)
      find_library(CHARSET_LIB NAMES charset libcharset)
    else()
      set(ICONV_LIB "")
      set(CHARSET_LIB "")
    endif()
    list(APPEND EXTRA_TARGET_LINK_LIBRARIES ${ICONV_LIB} ${CHARSET_LIB})
  endif()

  if(WIN32 OR MSYS)
    find_package(iconv)

    if(iconv_FOUND)
      set(HAVE_ICONV TRUE)
      include_directories(${ICONV_INCLUDE_DIR})
      list(APPEND EXTRA_TARGET_LINK_LIBRARIES ${ICONV_LIBRARIES})
      if(${ICONV_SECOND_ARGUMENT_IS_CONST})
        set(ICONV_CONST "const")
      endif()
      # this is really just a hack for conda
      if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
        if(DEFINED ENV{CONDA_PREFIX})
          add_compile_definitions(HAVE_LOCALE_CHARSET)
          find_library(CHARSET_LIB NAMES charset libcharset)
          list(APPEND EXTRA_TARGET_LINK_LIBRARIES ${CHARSET_LIB})
        endif()
      endif()
    else()
      message(WARNING "No iconv support")
    endif()
  endif()

  message(STATUS "Possible iconv include directory: ${ICONV_INCLUDE_DIR}")
  message(STATUS "Possible extra link libraries found: ${EXTRA_TARGET_LINK_LIBRARIES}")

  add_executable(trietool tools/trietool.c)
  #target_include_directories(trietool
    #PUBLIC
    #${ICONV_INCLUDE_DIR}
    #)

  target_link_libraries(trietool
    datrie
    ${EXTRA_TARGET_LINK_LIBRARIES}
    )

  install(
      TARGETS trietool
      RUNTIME DESTINATION bin
    )
endif()

install(FILES ${LIBDATRIE_HEADERS}
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

if(BUILD_SHARED_LIBS)
  list(APPEND LIBDATRIE_LIBS datrie)
endif()

if(BUILD_STATIC_LIBS)
  list(APPEND LIBDATRIE_LIBS datriestatic)
endif()

install(TARGETS ${LIBDATRIE_LIBS} EXPORT datrieConfig
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT datrieConfig
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/datrie NAMESPACE datrie::)

# generate CONFIG_H
set(CONFIG_H ${CMAKE_CURRENT_SOURCE_DIR}/config.h)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake ${CONFIG_H})

set(LIBDATRIE_PC ${CMAKE_CURRENT_BINARY_DIR}/datrie.pc)
configure_file( ${CMAKE_CURRENT_SOURCE_DIR}/datrie.pc.in ${LIBDATRIE_PC} @ONLY)
install(FILES ${LIBDATRIE_PC} DESTINATION ${INSTALL_PKGCONFIG_DIR})
