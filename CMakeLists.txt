cmake_minimum_required(VERSION 4.0.1)

project(fcitx5-macos VERSION 0.2.4 LANGUAGES CXX Swift)

list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# On x86 /Library/Frameworks/Mono.framework will mess up libintl.
set(CMAKE_FIND_FRAMEWORK LAST)

if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

# Starting from cmake 4.0, CMAKE_OSX_SYSROOT defaults to empty.
execute_process(COMMAND xcrun --sdk macosx --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CMAKE_OSX_DEPLOYMENT_TARGET 13.3)
set(F5M_TARGET "${CMAKE_OSX_ARCHITECTURES}-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")
add_compile_options(-target "${F5M_TARGET}")
add_link_options(-target "${F5M_TARGET}")

# Disallow InitializeSwift to execute link_directories which adds Xcode paths to rpath.
set(SWIFT_LIBRARY_SEARCH_PATHS "")
include(InitializeSwift)
include(AddSwift)

set(CMAKE_CXX_STANDARD 20)

set(FIND_ROOT_PATH "${PROJECT_BINARY_DIR}/usr")
set(PREBUILDER_INCLUDE_DIR "${FIND_ROOT_PATH}/include")
set(PREBUILDER_LIB_DIR "${FIND_ROOT_PATH}/lib")
set(PREBUILDER_SHARE_DIR "${FIND_ROOT_PATH}/share")

list(APPEND CMAKE_FIND_ROOT_PATH "${FIND_ROOT_PATH}")

set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PROJECT_BINARY_DIR}")
set(ENV{PKG_CONFIG_PATH} "${PREBUILDER_LIB_DIR}/pkgconfig;${PREBUILDER_SHARE_DIR}/pkgconfig")

add_library(Libuv_static STATIC IMPORTED)
set_target_properties(Libuv_static PROPERTIES
    IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libuv.a"
    INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
)
set(LIBUV_TARGET Libuv_static)

option(ENABLE_TESTING_ADDONS "" OFF)
option(ENABLE_TEST "" OFF)
option(ENABLE_COVERAGE "" OFF)
option(ENABLE_ENCHANT "" OFF)
option(ENABLE_X11 "" OFF)
option(ENABLE_WAYLAND "" OFF)
option(ENABLE_DBUS "" OFF)
option(ENABLE_DOC "" OFF)
option(ENABLE_SERVER "" OFF)
option(USE_SYSTEMD "" OFF)
option(ENABLE_XDGAUTOSTART "" OFF)
option(ENABLE_EMOJI "" OFF)
option(ENABLE_LIBUUID "" OFF)
option(ENABLE_ASAN "Enable Address Sanitizer" OFF)

if(ENABLE_ASAN)
  include(AddressSanitizer)
endif()

set(APP_INSTALL_PATH "/Library/Input Methods")
set(CMAKE_INSTALL_PREFIX "${APP_INSTALL_PATH}/Fcitx5.app/Contents")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
# Reproducible
set(CMAKE_INSTALL_LIBDATADIR "${CMAKE_INSTALL_PREFIX}/lib")

# Override iso-codes paths and xkb default rules file
set(ISOCODES_ISO3166_JSON "${CMAKE_INSTALL_PREFIX}/share/iso-codes/json/iso_3166-1.json")
set(ISOCODES_ISO639_JSON "${CMAKE_INSTALL_PREFIX}/share/iso-codes/json/iso_639-3.json")
set(XKEYBOARDCONFIG_XKBBASE "${CMAKE_INSTALL_PREFIX}/share/X11/xkb")
set(XKEYBOARDCONFIG_DATADIR "${CMAKE_INSTALL_PREFIX}/share")

add_subdirectory(fcitx5)
add_subdirectory(deps)

add_subdirectory(logging)

set(WKWEBVIEW_PROTOCOL "fcitx")
set(WEBVIEW_WWW_PATH ".local/share/fcitx5/www")

include_directories(
    fcitx5-webview/include
    fcitx5-webview/webview
    "${PREBUILDER_INCLUDE_DIR}" # nlohmann-json
)

add_compile_definitions($<$<COMPILE_LANGUAGE:C,CXX>:-DFCITX_GETTEXT_DOMAIN=\"fcitx5-macos\">)

add_subdirectory(keycode)
add_subdirectory(macosfrontend)
add_subdirectory(macosnotifications)

option(BUILD_PREVIEW "" OFF)
add_subdirectory(fcitx5-webview)
add_subdirectory(webpanel)

set(BUILD_SHARED_FCITX_ADDON OFF)
include(fcitx5/src/lib/fcitx-utils/Fcitx5Macros.cmake)
add_subdirectory(fcitx5-beast/src)

add_subdirectory(src)
add_subdirectory(assets)

enable_testing()
add_subdirectory(tests)
