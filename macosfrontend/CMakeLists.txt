add_definitions(-DFCITX_GETTEXT_DOMAIN=\"fcitx5-macos\")

add_library(macosfrontend STATIC macosfrontend.cpp)
target_link_libraries(macosfrontend Fcitx5::Core)

configure_file(macosfrontend.conf.in.in macosfrontend.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/macosfrontend.conf.in macosfrontend.conf)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/macosfrontend.conf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/fcitx5/addon"
)
