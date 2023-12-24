_swift_generate_cxx_header_target(
    nativelog_swift_h
    SwiftNativeLog
    "${CMAKE_CURRENT_BINARY_DIR}/include/nativelog-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/nativelog.swift"
)

add_library(SwiftNativeLog STATIC nativelog.swift)
add_dependencies(SwiftNativeLog nativelog_swift_h)
set_target_properties(SwiftNativeLog PROPERTIES Swift_MODULE_NAME SwiftNativeLog)
target_compile_options(SwiftNativeLog PUBLIC
  "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

_swift_generate_cxx_header_target(
    fcitx_swift_h
    SwiftFcitx
    "${CMAKE_CURRENT_BINARY_DIR}/include/fcitx-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/fcitx.swift"
)

add_library(SwiftFcitx STATIC fcitx.swift)
add_dependencies(SwiftFcitx fcitx_swift_h)
set_target_properties(SwiftFcitx PROPERTIES Swift_MODULE_NAME SwiftFcitx)
target_compile_options(SwiftFcitx PUBLIC
  "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

add_executable(Fcitx5
    MACOSX_BUNDLE
    server.swift
    controller.swift
    fcitx.cpp
)

add_dependencies(Fcitx5 macosfrontend)

target_include_directories(Fcitx5 PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")

target_link_libraries(Fcitx5
    "-Xlinker -rpath -Xlinker '${CMAKE_INSTALL_PREFIX}/lib'"
    SwiftNativeLog
    SwiftFcitx
    Fcitx5::Core
    macosfrontend
)

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents")

set(BINARY_LIB_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/lib")
set(BINARY_MODULE_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

add_custom_command(TARGET Fcitx5 POST_BUILD
    COMMAND rm -f "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents/Macos/Fcitx5.d"
)

install(TARGETS Fcitx5
    BUNDLE DESTINATION "${APP_INSTALL_PATH}"
)
