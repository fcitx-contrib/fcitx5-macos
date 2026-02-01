add_executable(get_im get_im.swift)
add_executable(switch_im switch_im.swift)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/fcitx.icns"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_26.pdf
    COMMAND SOURCE_DATE_EPOCH=0 rsvg-convert -f pdf -o ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_26.pdf ${CMAKE_CURRENT_SOURCE_DIR}/penguin-26.svg
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/penguin-26.svg
)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_15.pdf
    COMMAND SOURCE_DATE_EPOCH=0 rsvg-convert -f pdf -o ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_15.pdf ${CMAKE_CURRENT_SOURCE_DIR}/penguin-15.svg
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/penguin-15.svg
)
add_custom_target(GeneratePDF ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_26.pdf ${CMAKE_CURRENT_BINARY_DIR}/menu_icon_15.pdf
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/menu_icon_26.pdf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/menu_icon_15.pdf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)
# When upgrade from old version, menu_icon.pdf will be used, so we have to make it the old version.
# Afterwards, script will copy the correct one to overwrite it.
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/menu_icon_15.pdf"
    RENAME menu_icon.pdf
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

# Preserve execution permission
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/uninstall.sh"
    "${CMAKE_CURRENT_SOURCE_DIR}/update.sh"
    "${CMAKE_CURRENT_BINARY_DIR}/get_im"
    "${CMAKE_CURRENT_BINARY_DIR}/switch_im"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)

install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/fcitx5-curl"
    "${CMAKE_CURRENT_SOURCE_DIR}/fcitx5-remote"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/bin"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/icons"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/iso-codes"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/xkeyboard-config-2"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

# iso_639-3.mo and xkeyboard-config.mo
install(DIRECTORY "${PREBUILDER_SHARE_DIR}/locale"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

#
# Swift i18n through Localizable.strings
# Use 'GenerateStrings' to update .strings files.
#
set(LOCALES en zh-Hans zh-Hant)

list(TRANSFORM LOCALES APPEND ".lproj" OUTPUT_VARIABLE LPROJS)
list(TRANSFORM LPROJS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE LPROJ_DIRS)
list(TRANSFORM LPROJ_DIRS APPEND "/Localizable.strings" OUTPUT_VARIABLE LOCALIZABLE_STRINGS_FILES)

file(GLOB_RECURSE LOCALIZABLE_SWIFT_SOURCES ${PROJECT_SOURCE_DIR}/src/*.swift)
list(APPEND LOCALIZABLE_SWIFT_SOURCES ${PROJECT_SOURCE_DIR}/macosnotifications/notify.swift)
add_custom_command(
    OUTPUT ${LOCALIZABLE_STRINGS_FILES}
    COMMAND genstrings ${LOCALIZABLE_SWIFT_SOURCES} -SwiftUI -o ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj
    COMMAND ${PROJECT_SOURCE_DIR}/scripts/update_translations.py ${LOCALIZABLE_STRINGS_FILES}
    DEPENDS ${LOCALIZABLE_SWIFT_SOURCES}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating Localizable.strings..."
)
add_custom_target(GenerateStrings
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj/Localizable.strings
)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/Base.lproj"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources"
)
foreach(LPROJ_DIR IN LISTS LPROJ_DIRS)
    install(DIRECTORY "${LPROJ_DIR}" DESTINATION "${CMAKE_INSTALL_PREFIX}/Resources")
endforeach()
