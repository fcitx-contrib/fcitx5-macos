execute_process(COMMAND git rev-parse HEAD
    OUTPUT_VARIABLE COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND git show --no-patch --format=%ct
    OUTPUT_VARIABLE UNIX_TIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
configure_file(config/meta.swift.in ${CMAKE_CURRENT_SOURCE_DIR}/config/meta.swift @ONLY)

file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_library(Fcitx5Objs STATIC
    fcitx.cpp
    tunnel.cpp
    config/config.cpp
)

target_link_libraries(Fcitx5Objs
    SwiftyJSON
    SwiftFrontend
    SwiftNotify
    Fcitx5::Core
    keyboard
    webpanel
    beast
    macosfrontend
    macosnotifications
    WebviewCandidateWindow
    Logging
)

add_executable(Fcitx5
    MACOSX_BUNDLE
    server.swift
    locale.swift
    controller.swift
    ${CONFIG_UI_FILES}
)

target_link_libraries(Fcitx5
    Fcitx5Objs
    AlertToast
    SwiftyJSON
    SwiftFrontend
    SwiftNotify
)

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents")

set(BINARY_LIB_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/lib")
set(BINARY_MODULE_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

add_custom_command(TARGET Fcitx5 POST_BUILD
    COMMAND rm -f "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents/MacOS/Fcitx5.d"
)

install(TARGETS Fcitx5
    BUNDLE DESTINATION "${APP_INSTALL_PATH}"
)
