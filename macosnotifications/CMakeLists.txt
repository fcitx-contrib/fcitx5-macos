add_definitions(-DFCITX_GETTEXT_DOMAIN=\"fcitx5-macos\")

_swift_generate_cxx_header_target(
  notify_swift_h
  SwiftNotify
  "${CMAKE_CURRENT_BINARY_DIR}/include/notify-swift.h"
  SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/notify.swift"
  SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}"
)

add_library(SwiftNotify STATIC notify.swift)
set_target_properties(SwiftNotify PROPERTIES Swift_MODULE_NAME SwiftNotify)
target_compile_options(SwiftNotify PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
add_dependencies(SwiftNotify notify_swift_h)
target_include_directories(SwiftNotify PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

add_library(macosnotifications STATIC macosnotifications.cpp)
target_link_libraries(macosnotifications SwiftNotify Fcitx5::Core Fcitx5::Module::Notifications)
target_include_directories(macosnotifications PUBLIC
  "${CMAKE_CURRENT_BINARY_DIR}/include"
  "${CMAKE_SOURCE_DIR}/src"
  "${CMAKE_SOURCE_DIR}/include"
)

configure_file(notifications.conf.in.in notifications.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/notifications.conf.in notifications.conf)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/notifications.conf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/fcitx5/addon"
)
