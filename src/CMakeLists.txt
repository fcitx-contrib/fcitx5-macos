execute_process(COMMAND git rev-parse HEAD
    OUTPUT_VARIABLE COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND git show --no-patch --format=%ct
    OUTPUT_VARIABLE UNIX_TIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND bash -c "git describe --exact-match || echo latest"
    OUTPUT_VARIABLE RELEASE_TAG
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
configure_file(config/meta.swift.in ${CMAKE_CURRENT_SOURCE_DIR}/config/meta.swift @ONLY)

file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_library(Fcitx5Objs STATIC
    fcitx.cpp
    tunnel.cpp
    config/config.cpp
)

option(VERBOSE_LOGGING "Enable verbose logging" ON)
if(VERBOSE_LOGGING)
    target_compile_definitions(Fcitx5Objs PRIVATE VERBOSE_LOGGING)
endif()

target_link_libraries(Fcitx5Objs
    Fcitx5::Core
    keyboard
    webpanel
    beast
    macosfrontend
    notifications
    WebviewCandidateWindow
)

add_executable(Fcitx5
    MACOSX_BUNDLE
    server.swift
    locale.swift
    controller.swift
    color.swift
    ${CONFIG_UI_FILES}
)

target_link_libraries(Fcitx5
    Fcitx5Objs
    AlertToast
    SwiftyJSON
    SwiftFrontend
    SwiftNotify
    Logging
)

fcitx5_import_addons(Fcitx5
    REGISTRY_VARNAME getStaticAddon
    ADDONS beast keyboard webpanel macosfrontend notifications
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
