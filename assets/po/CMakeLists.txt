#
# C++ i18n through gettext
# Use 'pot' to generate the POT file.
#
set(TRANSLATABLE_CXX_SOURCES
    macosfrontend/macosfrontend.h
    macosnotifications/macosnotifications.h
    webpanel/webpanel.h
)

list(TRANSFORM TRANSLATABLE_CXX_SOURCES PREPEND "${PROJECT_SOURCE_DIR}/" OUTPUT_VARIABLE TRANSLATABLE_CXX_SOURCES_FULL_PATH)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/base.pot
    COMMAND xgettext --c++ --keyword=_ --keyword=N_ ${TRANSLATABLE_CXX_SOURCES} -o ${CMAKE_CURRENT_SOURCE_DIR}/base.pot
    DEPENDS ${TRANSLATABLE_CXX_SOURCES_FULL_PATH}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMENT "Generating base.pot..."
)
add_custom_target(pot
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/base.pot
)

set(FCITX_INSTALL_LOCALEDIR "${CMAKE_INSTALL_PREFIX}/share/locale")
fcitx5_install_translation(fcitx5-macos)
