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
#
# Swift i18n through Localizable.strings
#
file(GLOB_RECURSE LOCALIZABLE_SWIFT_SOURCES ${CMAKE_SOURCE_DIR}/src/*.swift)
set(LOCALIZABLE_STRINGS_FILES
    ${PROJECT_SOURCE_DIR}/assets/en.lproj/Localizable.strings
    ${PROJECT_SOURCE_DIR}/assets/zh-Hans.lproj/Localizable.strings
)
add_custom_command(
    OUTPUT ${LOCALIZABLE_STRINGS_FILES}
    COMMAND genstrings ${LOCALIZABLE_SWIFT_SOURCES} -SwiftUI -o ${PROJECT_SOURCE_DIR}/assets/en.lproj
    COMMAND ${PROJECT_SOURCE_DIR}/assets/update_translations.py ${LOCALIZABLE_STRINGS_FILES}
    DEPENDS ${LOCALIZABLE_SWIFT_SOURCES}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating Localizable.strings..."
)
add_custom_target(GenerateStrings
    DEPENDS ${PROJECT_SOURCE_DIR}/assets/en.lproj/Localizable.strings
)

