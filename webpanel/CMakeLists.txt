add_library(webpanel STATIC webpanel.cpp tunnel.cpp)
target_link_libraries(webpanel Fcitx5::Core)
target_include_directories(webpanel PRIVATE "${PROJECT_SOURCE_DIR}/src")

configure_file(webpanel.conf.in.in webpanel.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/webpanel.conf.in webpanel.conf)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/webpanel.conf"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/share/fcitx5/addon"
)
