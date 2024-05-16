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

install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/fcitx5-curl"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/bin"
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

install(DIRECTORY "${PREBUILT_INSTALL_PATH}/share/iso-codes"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

install(DIRECTORY "${PREBUILT_INSTALL_PATH}/share/X11"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share"
)

#
# Swift i18n through Localizable.strings
# Use 'GenerateStrings' to update .strings files.
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

#
# C++ i18n through gettext
# Use 'pot' to generate the POT file.
#
set(TRANSLATABLE_CXX_SOURCES
    src/*.cpp
    src/*.h
    macosfrontend/*.cpp
    macosfrontend/*.h
    macosnotifications/*.cpp
    macosnotifications/*.h
    webpanel/*.cpp
    webpanel/*.h
)
add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/assets/po/base.pot
    COMMAND xgettext --c++ --keyword=_ ${TRANSLATABLE_CXX_SOURCES} -o ${CMAKE_SOURCE_DIR}/assets/po/base.pot
    DEPENDS ${LOCALIZABLE_CXX_SOURCES}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Generating base.pot..."
)
add_custom_target(pot
    DEPENDS ${CMAKE_SOURCE_DIR}/assets/po/base.pot
)

foreach(LOCALE zh_CN)
    set(MO_FILE ${CMAKE_CURRENT_BINARY_DIR}/po/${LOCALE}.mo)
    add_custom_command(
        OUTPUT ${MO_FILE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/po/${LOCALE}.po
        COMMAND msgfmt ${CMAKE_CURRENT_SOURCE_DIR}/po/${LOCALE}.po -o ${MO_FILE}
    )
    add_custom_target(${LOCALE}_mo ALL DEPENDS ${MO_FILE})
    install(FILES ${MO_FILE}
        DESTINATION ${CMAKE_INSTALL_PREFIX}/share/locale/${LOCALE}/LC_MESSAGES
        RENAME fcitx5-macos.mo
    )
endforeach()
