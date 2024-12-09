add_library(SwiftNotify STATIC notify.swift)
set_target_properties(SwiftNotify PROPERTIES Swift_MODULE_NAME SwiftNotify)
target_compile_options(SwiftNotify PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
target_include_directories(SwiftNotify PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}" "${PROJECT_BINARY_DIR}/logging")
add_dependencies(SwiftNotify Logging)

_swift_generate_cxx_header(
    SwiftNotify
    "${CMAKE_CURRENT_BINARY_DIR}/include/notify-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/notify.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR};${PROJECT_BINARY_DIR}/logging"
    DEPENDS Logging
)

add_library(notifications STATIC macosnotifications.cpp)
add_dependencies(notifications SwiftNotify)
target_link_libraries(notifications Fcitx5::Core Fcitx5::Module::Notifications)
target_include_directories(notifications PUBLIC
  "${CMAKE_CURRENT_BINARY_DIR}/include"
  "${CMAKE_SOURCE_DIR}/src"
)

configure_file(notifications.conf.in.in notifications.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/notifications.conf.in notifications.conf)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/notifications.conf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/fcitx5/addon"
)
