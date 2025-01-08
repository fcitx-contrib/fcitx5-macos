add_executable(switch_im switch_im.swift)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/fcitx.icns"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/menu_icon.pdf
    COMMAND SOURCE_DATE_EPOCH=0 rsvg-convert -f pdf -o ${CMAKE_CURRENT_BINARY_DIR}/menu_icon.pdf ${CMAKE_CURRENT_SOURCE_DIR}/penguin.svg
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/penguin.svg
)
add_custom_target(GeneratePDF ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/menu_icon.pdf
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/menu_icon.pdf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

# Preserve execution permission
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/uninstall.sh"
    "${CMAKE_CURRENT_SOURCE_DIR}/update.sh"
    "${CMAKE_CURRENT_BINARY_DIR}/switch_im"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/fcitx5-curl"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/bin"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/icons"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/iso-codes"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/X11"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

#
# Swift i18n through Localizable.strings
# Use 'GenerateStrings' to update .strings files.
#
file(GLOB_RECURSE LOCALIZABLE_SWIFT_SOURCES ${CMAKE_SOURCE_DIR}/src/*.swift)
set(LOCALIZABLE_STRINGS_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj/Localizable.strings
    ${CMAKE_CURRENT_SOURCE_DIR}/zh-Hans.lproj/Localizable.strings
)
add_custom_command(
    OUTPUT ${LOCALIZABLE_STRINGS_FILES}
    COMMAND genstrings ${LOCALIZABLE_SWIFT_SOURCES} -SwiftUI -o ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/update_translations.py ${LOCALIZABLE_STRINGS_FILES}
    DEPENDS ${LOCALIZABLE_SWIFT_SOURCES}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating Localizable.strings..."
)
add_custom_target(GenerateStrings
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj/Localizable.strings
)

foreach(LOCALE
    Base
    en
    zh-Hans
    zh-Hant
)
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${LOCALE}.lproj"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
    )
endforeach()

add_subdirectory(po)
