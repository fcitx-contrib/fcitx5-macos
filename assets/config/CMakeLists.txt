add_executable(switch_im switch_im.swift)

# Preserve execution permission
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/uninstall.sh"
    "${CMAKE_CURRENT_SOURCE_DIR}/update.sh"
    "${CMAKE_CURRENT_BINARY_DIR}/switch_im"
    DESTINATION "${CONFIGTOOL_INSTALL_PATH}/Resources"
)

foreach(LOCALE
    Base
    en
    zh-Hans
)
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${LOCALE}.lproj"
        DESTINATION "${CONFIGTOOL_INSTALL_PATH}/Resources"
    )
endforeach()
