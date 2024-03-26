add_executable(switch_im switch_im.swift)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/fcitx.icns"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

# Preserve execution permission
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/uninstall.sh"
    "${CMAKE_CURRENT_SOURCE_DIR}/update.sh"
    "${CMAKE_CURRENT_BINARY_DIR}/switch_im"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/Base.lproj"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/en.lproj"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/zh-Hans.lproj"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/zh-Hant.lproj"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(DIRECTORY "${PREBUILT_INSTALL_PATH}/share/icons"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)
