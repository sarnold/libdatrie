# This module finds headers and the iconv library.
# Results are reported in variables:
#  ICONV_FOUND           - True if headers and library were found
#  ICONV_INCLUDE_DIRS    - libiconv include directories
#  ICONV_LIBRARIES       - libiconv library to be linked

find_path(ICONV_INCLUDE_DIR
  NAMES iconv.h
  HINTS
    ${CMAKE_PREFIX_PATH}
    $ENV{CONDA_PREFIX}
    $ENV{VCPKG_ROOT}
  PATH_SUFFIXES include include/iconv
  PATHS
    ~/Library/Frameworks
    /Library/Frameworks
    /opt/local
    /opt
    /usr
    /usr/local/
)

find_library(ICONV_LIBRARY
  NAMES iconv libiconv libiconv2 c
  HINTS
    ${CMAKE_PREFIX_PATH}
    $ENV{CONDA_PREFIX}
    $ENV{VCPKG_ROOT}
  PATH_SUFFIXES lib lib64 lib32
  PATHS
    ~/Library/Frameworks
    /Library/Frameworks
    /opt/local
    /opt
    /usr
    /usr/local/
)

if(ICONV_INCLUDE_DIR AND NOT ICONV_LIBRARY)
  include(CheckFunctionExists)
  check_function_exists(iconv HAVE_ICONV_IN_LIBC)
  if(HAVE_ICONV_IN_LIBC)
    set(HAVE_ICONV_IN_LIBC "${HAVE_ICONV_IN_LIBC}" CACHE INTERNAL "")
    set(ICONV_LIBRARY "bundled in local libc" CACHE INTERNAL "")
  endif()
endif()

if(ICONV_INCLUDE_DIR AND ICONV_LIBRARY)
  set(ICONV_FOUND ON CACHE INTERNAL "")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ICONV
  REQUIRED_VARS ICONV_LIBRARY ICONV_INCLUDE_DIR)

if(ICONV_FOUND)
  # need if _FOUND guard to allow project to autobuild; can't overwrite imported target even if bad
  if(NOT ICONV_FIND_QUIETLY)
    message(STATUS "Found iconv library: ${ICONV_LIBRARY}")
  endif()

  if(HAVE_ICONV_IN_LIBC)
    set(_lib_type INTERFACE)
  else()
    set(_lib_type UNKNOWN)
  endif()

  add_library(Iconv::Iconv ${_lib_type} IMPORTED)
  set_target_properties(Iconv::Iconv PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ICONV_INCLUDE_DIR}")

  if(NOT HAVE_ICONV_IN_LIBC)
    set_target_properties(Iconv::Iconv PROPERTIES
      IMPORTED_LOCATION "${ICONV_LIBRARY}")
  endif()

  unset(_lib_type)
else()
  if(ICONV_FIND_REQUIRED)
    message(FATAL_ERROR "Could NOT find iconv library")
  endif()
endif(ICONV_FOUND)

mark_as_advanced(ICONV_INCLUDE_DIR ICONV_LIBRARY)
