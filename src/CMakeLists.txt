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
    config/menu.swift
    config/about.swift
    fcitx.cpp
    keycode.cpp
)

add_dependencies(Fcitx5 macosfrontend macosnotifications)

target_include_directories(Fcitx5 PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")
target_include_directories(Fcitx5 PRIVATE
    "${PROJECT_SOURCE_DIR}/fcitx5/src/im/keyboard"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase/"
    "${CMAKE_CURRENT_BINARY_DIR}/../fcitx5"
)

target_link_libraries(Fcitx5
    "-Xlinker -rpath -Xlinker '${CMAKE_INSTALL_PREFIX}/lib'"
    SwiftFcitx
    SwiftNotify
    Fcitx5::Core
    keyboard
    macosfrontend
    macosnotifications
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

if(ENABLE_CODESIGN)
  add_custom_command(TARGET Fcitx5 POST_BUILD
    COMMAND /usr/bin/codesign --force --sign - --timestamp --options runtime $<TARGET_FILE:Fcitx5>
    COMMENT "Signing the executable..."
  )
endif()
