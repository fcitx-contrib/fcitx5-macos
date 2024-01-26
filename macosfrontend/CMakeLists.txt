add_definitions(-DFCITX_GETTEXT_DOMAIN=\"fcitx5-macos\")

_swift_generate_cxx_header_target(
    macosfrontend_swift_h
    SwiftFrontend
    "${CMAKE_CURRENT_BINARY_DIR}/include/macosfrontend-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/macosfrontend.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}"
)

add_library(SwiftFrontend STATIC macosfrontend.swift)
set_target_properties(SwiftFrontend PROPERTIES Swift_MODULE_NAME SwiftFrontend)
target_compile_options(SwiftFrontend PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
add_dependencies(SwiftFrontend macosfrontend_swift_h)
target_include_directories(SwiftFrontend PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

add_library(macosfrontend STATIC macosfrontend.cpp keycode.cpp)
add_dependencies(macosfrontend SwiftFrontend)
target_link_libraries(macosfrontend Fcitx5::Core)
target_include_directories(macosfrontend PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
    "${CMAKE_SOURCE_DIR}/src"
)

configure_file(macosfrontend.conf.in.in macosfrontend.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/macosfrontend.conf.in macosfrontend.conf)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/macosfrontend.conf"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/fcitx5/addon"
)
