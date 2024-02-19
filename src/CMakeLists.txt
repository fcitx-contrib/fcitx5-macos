file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_library(Fcitx5Objs STATIC
    fcitx.cpp
    config/config.cpp
    controller.swift
    ${CONFIG_UI_FILES}
)

target_include_directories(Fcitx5Objs PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/im/keyboard"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase/"
    "${CMAKE_CURRENT_BINARY_DIR}/../fcitx5"
)
target_link_libraries(Fcitx5Objs
    "-Xlinker -rpath -Xlinker '${CMAKE_INSTALL_PREFIX}/lib'"
    SwiftyJSON
    SwiftFrontend
    SwiftNotify
    Fcitx5::Core
    keyboard
    webpanel
    macosfrontend
    macosnotifications
    WebviewCandidateWindow
    Logging
)

add_executable(Fcitx5
    MACOSX_BUNDLE
    server.swift
    controller.swift
    ${CONFIG_UI_FILES}
)

target_link_libraries(Fcitx5 Fcitx5Objs)

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents")

set(BINARY_LIB_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/lib")
set(BINARY_MODULE_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

add_custom_command(TARGET Fcitx5 POST_BUILD
    COMMAND rm -f "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents/Macos/Fcitx5.d"
)

install(TARGETS Fcitx5
    BUNDLE DESTINATION "${APP_INSTALL_PATH}"
)
