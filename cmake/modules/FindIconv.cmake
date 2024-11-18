# This module finds headers and the iconv library.
# Results are reported in variables:
#  ICONV_FOUND           - True if headers and library were found
#  ICONV_INCLUDE_DIRS    - libiconv include directories
#  ICONV_LIBRARIES       - libiconv/libcharset libraries to be linked
#
MACRO (TRY_MACRO_FOR_LIBRARY INCLUDES LIBRARIES
       TRY_TYPE SAMPLE_SOURCE MACRO_LIST)
  IF(WIN32 AND NOT CYGWIN)
    SET(CMAKE_REQUIRED_INCLUDES ${INCLUDES})
    SET(CMAKE_REQUIRED_LIBRARIES ${LIBRARIES})
    FOREACH(VAR ${MACRO_LIST})
      # Clear ${VAR} from CACHE If the libraries which ${VAR} was
      # checked with are changed.
      SET(VAR_WITH_LIB "${VAR}_WITH_LIB")
      GET_PROPERTY(PREV_VAR_WITH_LIB VARIABLE PROPERTY ${VAR_WITH_LIB})
      IF(NOT "${PREV_VAR_WITH_LIB}" STREQUAL "${LIBRARIES}")
        UNSET(${VAR} CACHE)
      ENDIF(NOT "${PREV_VAR_WITH_LIB}" STREQUAL "${LIBRARIES}")
      # Check if the library can be used with the macro.
      IF("${TRY_TYPE}" MATCHES "COMPILES")
        CHECK_C_SOURCE_COMPILES("${SAMPLE_SOURCE}" ${VAR})
      ELSEIF("${TRY_TYPE}" MATCHES "RUNS")
        CHECK_C_SOURCE_RUNS("${SAMPLE_SOURCE}" ${VAR})
      ELSE("${TRY_TYPE}" MATCHES "COMPILES")
        MESSAGE(FATAL_ERROR "UNKNOWN KEYWORD \"${TRY_TYPE}\" FOR TRY_TYPE")
      ENDIF("${TRY_TYPE}" MATCHES "COMPILES")
      # Save the libraries which ${VAR} is checked with.
      SET(${VAR_WITH_LIB} "${LIBRARIES}" CACHE INTERNAL
          "Macro ${VAR} is checked with")
    ENDFOREACH(VAR)
  ENDIF(WIN32 AND NOT CYGWIN)
ENDMACRO (TRY_MACRO_FOR_LIBRARY)

MACRO(CHECK_ICONV LIB TRY_ICONV_CONST)
  IF(NOT HAVE_ICONV)
    IF (CMAKE_C_COMPILER_ID MATCHES "^GNU$" OR
        CMAKE_C_COMPILER_ID MATCHES "^Clang$")
      #
      # During checking iconv proto type, we should use -Werror to avoid the
      # success of iconv detection with a warnig which success is a miss
      # detection. So this needs for all build mode(even it's a release mode).
      #
      SET(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -Werror")
    ENDIF (CMAKE_C_COMPILER_ID MATCHES "^GNU$" OR
           CMAKE_C_COMPILER_ID MATCHES "^Clang$")
    IF (MSVC)
      # NOTE: /WX option is the same as gcc's -Werror option.
      SET(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} /WX")
    ENDIF (MSVC)
    #
    CHECK_C_SOURCE_COMPILES(
      "#include <stdlib.h>
       #include <iconv.h>
       int main() {
          ${TRY_ICONV_CONST} char *ccp;
          iconv_t cd = iconv_open(\"\", \"\");
          iconv(cd, &ccp, (size_t *)0, (char **)0, (size_t *)0);
          iconv_close(cd);
          return 0;
       }"
     HAVE_ICONV_${LIB}_${TRY_ICONV_CONST})
    IF(HAVE_ICONV_${LIB}_${TRY_ICONV_CONST})
      SET(HAVE_ICONV true)
      SET(ICONV_CONST ${TRY_ICONV_CONST})
    ENDIF(HAVE_ICONV_${LIB}_${TRY_ICONV_CONST})
  ENDIF(NOT HAVE_ICONV)
ENDMACRO(CHECK_ICONV TRY_ICONV_CONST)

FIND_PATH(ICONV_INCLUDE_DIR iconv.h)
IF(ICONV_INCLUDE_DIR)
  SET(HAVE_ICONV_H 1)
  INCLUDE_DIRECTORIES(${ICONV_INCLUDE_DIR})
  SET(CMAKE_REQUIRED_INCLUDES ${ICONV_INCLUDE_DIR})
  CHECK_ICONV("libc" "const")
  CHECK_ICONV("libc" "")

  # If iconv isn't in libc and we have a libiconv, try that.
  FIND_LIBRARY(LIBICONV_PATH NAMES iconv libiconv libiconv-2)
  IF(NOT HAVE_ICONV AND LIBICONV_PATH)
    LIST(APPEND CMAKE_REQUIRED_LIBRARIES ${LIBICONV_PATH})
    # Test if a macro is needed for the library.
    TRY_MACRO_FOR_LIBRARY(
      "${ICONV_INCLUDE_DIR}" "${LIBICONV_PATH}"
      COMPILES
      "#include <iconv.h>\nint main() {return iconv_close((iconv_t)0);}"
      "WITHOUT_LIBICONV_STATIC;LIBICONV_STATIC")
    IF(NOT WITHOUT_LIBICONV_STATIC AND LIBICONV_STATIC)
      ADD_DEFINITIONS(-DLIBICONV_STATIC)
    ENDIF(NOT WITHOUT_LIBICONV_STATIC AND LIBICONV_STATIC)
    #
    # Set up CMAKE_REQUIRED_* for CHECK_ICONV
    #
    SET(CMAKE_REQUIRED_INCLUDES ${ICONV_INCLUDE_DIR})
    SET(CMAKE_REQUIRED_LIBRARIES ${LIBICONV_PATH})
    IF(LIBICONV_STATIC)
      # LIBICONV_STATIC is necessary for the success of CHECK_ICONV
      # on Windows.
      SET(CMAKE_REQUIRED_DEFINITIONS "-DLIBICONV_STATIC")
    ELSE(LIBICONV_STATIC)
      SET(CMAKE_REQUIRED_DEFINITIONS)
    ENDIF(LIBICONV_STATIC)
    CHECK_ICONV("libiconv" "const")
    CHECK_ICONV("libiconv" "")
    IF (HAVE_ICONV)
      LIST(APPEND ICONV_LIBRARIES ${LIBICONV_PATH})
    ENDIF(HAVE_ICONV)
  ENDIF(NOT HAVE_ICONV AND LIBICONV_PATH)
ENDIF(ICONV_INCLUDE_DIR)
#
# Find locale_charset() for libiconv (note we do not check for langinfo_codeset)
#
IF(LIBICONV_PATH)
  SET(CMAKE_REQUIRED_DEFINITIONS)
  SET(CMAKE_REQUIRED_INCLUDES ${ICONV_INCLUDE_DIR})
  SET(CMAKE_REQUIRED_LIBRARIES)
  CHECK_INCLUDE_FILES("localcharset.h" HAVE_LOCALCHARSET_H)
  FIND_LIBRARY(LIBCHARSET_PATH NAMES charset libcharset)
  IF(LIBCHARSET_PATH)
    SET(CMAKE_REQUIRED_LIBRARIES ${LIBCHARSET_PATH})
    IF(WIN32 AND NOT CYGWIN)
      # Test if a macro is needed for the library.
      TRY_MACRO_FOR_LIBRARY(
        "${ICONV_INCLUDE_DIR}" "${LIBCHARSET_PATH}"
        COMPILES
        "#include <localcharset.h>\nint main() {return locale_charset()?1:0;}"
        "WITHOUT_LIBCHARSET_STATIC;LIBCHARSET_STATIC")
      IF(NOT WITHOUT_LIBCHARSET_STATIC AND LIBCHARSET_STATIC)
        ADD_DEFINITIONS(-DLIBCHARSET_STATIC)
      ENDIF(NOT WITHOUT_LIBCHARSET_STATIC AND LIBCHARSET_STATIC)
      IF(WITHOUT_LIBCHARSET_STATIC OR LIBCHARSET_STATIC)
        SET(HAVE_LOCALE_CHARSET ON CACHE INTERNAL
            "Have function locale_charset")
      ENDIF(WITHOUT_LIBCHARSET_STATIC OR LIBCHARSET_STATIC)
    ELSE(WIN32 AND NOT CYGWIN)
      check_symbol_exists(locale_charset "localcharset.h" HAVE_LOCALE_CHARSET)
    ENDIF(WIN32 AND NOT CYGWIN)
    IF(HAVE_LOCALE_CHARSET)
      LIST(APPEND ICONV_LIBRARIES ${LIBCHARSET_PATH})
    ENDIF(HAVE_LOCALE_CHARSET)
  ENDIF(LIBCHARSET_PATH)
ENDIF(LIBICONV_PATH)

if(ICONV_INCLUDE_DIR)
  set(ICONV_FOUND ON CACHE INTERNAL "")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ICONV
  REQUIRED_VARS ICONV_INCLUDE_DIR)

mark_as_advanced(ICONV_INCLUDE_DIR)

if(ICONV_FOUND)
  # need if _FOUND guard to allow project to autobuild; can't overwrite imported target even if bad
  if(NOT ICONV_FIND_QUIETLY)
    message(STATUS "Found iconv include directory: ${ICONV_INCLUDE_DIR}")
    message(STATUS "Maybe found library path: ${LIBICONV_PATH}")
    message(STATUS "Maybe found libs: ${ICONV_LIBRARIES}")
  endif()

  if(NOT TARGET Iconv::Iconv)
    add_library(Iconv::Iconv INTERFACE IMPORTED)
    set_target_properties(Iconv::Iconv PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${ICONV_INCLUDE_DIR}")
  endif()

  if(NOT HAVE_ICONV_IN_LIBC)
    set_target_properties(Iconv::Iconv PROPERTIES
      IMPORTED_LOCATION "${ICONV_LIBRARIES}")
  endif()
else()
  if(ICONV_FIND_REQUIRED)
    message(FATAL_ERROR "Could NOT find iconv library")
  endif()
endif(ICONV_FOUND)
