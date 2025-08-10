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

install(DIRECTORY "${PREBUILDER_SHARE_DIR}/xkeyboard-config-2"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

#
# Swift i18n through Localizable.strings
# Use 'GenerateStrings' to update .strings files.
#
set(LOCALES en zh-Hans)

list(TRANSFORM LOCALES APPEND ".lproj" OUTPUT_VARIABLE LPROJS)
list(TRANSFORM LPROJS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE LPROJ_DIRS)
list(TRANSFORM LPROJ_DIRS APPEND "/Localizable.strings" OUTPUT_VARIABLE LOCALIZABLE_STRINGS_FILES)

file(GLOB_RECURSE LOCALIZABLE_SWIFT_SOURCES ${CMAKE_SOURCE_DIR}/src/*.swift)
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

add_subdirectory(po)
