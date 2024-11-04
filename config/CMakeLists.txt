execute_process(COMMAND git rev-parse HEAD
    OUTPUT_VARIABLE COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND git show --no-patch --format=%ct
    OUTPUT_VARIABLE UNIX_TIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
configure_file(meta.swift.in ${CMAKE_CURRENT_SOURCE_DIR}/meta.swift @ONLY)

file(GLOB CONFIG_SRCS CONFIGURE_DEPENDS *.swift)

add_executable(Fcitx5ConfigTool
    MACOSX_BUNDLE
    "${PROJECT_SOURCE_DIR}/src/config/util.swift"  # XXX
    "${PROJECT_SOURCE_DIR}/src/config/ui.swift"  # XXX
    ${CONFIG_SRCS}
)

set_target_properties(Fcitx5ConfigTool PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
)

target_link_libraries(Fcitx5ConfigTool
    AlertToast
    Logging
)

set(CONFIGTOOL_CONTENTS_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5ConfigTool.app/Contents")
set(CONFIGTOOL_RESOURCES_BINARY_DIR "${CONFIGTOOL_CONTENTS_BINARY_DIR}/Resources")

add_custom_command(TARGET Fcitx5ConfigTool POST_BUILD
    COMMAND rm -f "${CONFIGTOOL_CONTENTS_BINARY_DIR}/MacOS/Fcitx5ConfigTool.d"
)

add_custom_command(TARGET Fcitx5ConfigTool POST_BUILD
    COMMAND mkdir -p "${CONFIGTOOL_RESOURCES_BINARY_DIR}"
    COMMAND ln -sf ../../../../Resources/fcitx.icns "${CONFIGTOOL_RESOURCES_BINARY_DIR}/fcitx.icns"
)

install(TARGETS Fcitx5ConfigTool
    BUNDLE DESTINATION "${CMAKE_INSTALL_PREFIX}/MacOS"
)
