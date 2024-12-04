cmake_minimum_required(VERSION 3.27)

project(fcitx5-macos VERSION 0.1.0 LANGUAGES CXX Swift)

list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_Swift_LANGUAGE_VRSION 5.9)

# On x86 /Library/Frameworks/Mono.framework will mess up libintl.
set(CMAKE_FIND_FRAMEWORK LAST)

include(InitializeSwift)
include(AddSwift)

set(CMAKE_CXX_STANDARD 17)

if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

set(CMAKE_OSX_DEPLOYMENT_TARGET 13)
add_definitions(-target "${CMAKE_OSX_ARCHITECTURES}-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")

set(FIND_ROOT_PATH "${PROJECT_BINARY_DIR}/sysroot/usr")
set(PREBUILDER_INCLUDE_DIR "${FIND_ROOT_PATH}/include")
set(PREBUILDER_LIB_DIR "${FIND_ROOT_PATH}/lib")
set(PREBUILDER_SHARE_DIR "${FIND_ROOT_PATH}/share")

list(APPEND CMAKE_FIND_ROOT_PATH "${FIND_ROOT_PATH}")

set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PROJECT_BINARY_DIR}/sysroot")
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

add_subdirectory(macosfrontend)
add_subdirectory(macosnotifications)
add_subdirectory(webpanel)

add_subdirectory(src)
add_subdirectory(assets)

option(BUILD_PREVIEW "" OFF)
add_subdirectory(fcitx5-webview)

set(ADDON_TYPE "StaticLibrary")
add_subdirectory(fcitx5-beast/src)

enable_testing()
add_subdirectory(tests)
