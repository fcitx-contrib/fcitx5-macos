# This source file is part of the Swift open source project
#
# Copyright (c) 2023 Apple Inc. and the Swift project authors.
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information

include(CheckCompilerFlag)

# Generate bridging header from Swift to C++
# NOTE: This logic will eventually be upstreamed into CMake
function(_swift_generate_cxx_header_target target module header)
  cmake_parse_arguments(ARG "" "" "SOURCES;SEARCH_PATHS;DEPENDS" ${ARGN})
  if(NOT ARG_SOURCES)
    message(FATAL_ERROR "No sources provided to 'swift_generate_cxx_header_target'")
  endif()

  if(ARG_SEARCH_PATHS)
    list(TRANSFORM ARG_SEARCH_PATHS PREPEND "-I")
  endif()

  if(APPLE)
    set(SDK_FLAGS "-sdk" "${CMAKE_OSX_SYSROOT}")
  elseif(WIN32)
    set(SDK_FLAGS "-sdk" "$ENV{SDKROOT}")
  endif()

  # swiftc requires imported modules have the same target when
  # cross-compiling.  This check only considers macOS.
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    set(TARGET_FLAGS "-target" "arm64-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")
  endif()

  add_custom_command(
    OUTPUT
      "${header}"
    COMMAND
      ${CMAKE_Swift_COMPILER} -frontend -typecheck
      ${ARG_SEARCH_PATHS}
      ${ARG_SOURCES}
      ${SDK_FLAGS}
      ${TARGET_FLAGS}
      -module-name "${module}"
      -cxx-interoperability-mode=default
      -emit-clang-header-path "${header}"
    DEPENDS
      ${ARG_DEPENDS}
      ${ARG_SOURCES}
    COMMENT
      "Generating '${header}'"
  )

  add_custom_target("${target}"
    DEPENDS
      "${header}"
  )
endfunction()
