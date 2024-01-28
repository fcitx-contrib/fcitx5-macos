cmake_minimum_required(VERSION 3.27)

project(fcitx5-macos VERSION 0.1.0 LANGUAGES CXX Swift)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(InitializeSwift)
include(AddSwift)

set(CMAKE_CXX_STANDARD 17)

if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

set(CMAKE_OSX_DEPLOYMENT_TARGET 13)

# Need HOMEBREW_PATH for iso-codes and xkeyboardconfig
if(CMAKE_OSX_ARCHITECTURES STREQUAL arm64)
    add_definitions(-target "arm64-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")
    set(HOMEBREW_PATH "/opt/homebrew")
else()
    set(HOMEBREW_PATH "/usr/local")
endif()

set(PREBUILT_INSTALL_PATH "/tmp/fcitx5")

set(ENV{PKG_CONFIG_PATH} "${PREBUILT_INSTALL_PATH}/lib/pkgconfig:${HOMEBREW_PATH}/share/pkgconfig")

# For dependencies not to be find via pkg-config
set(LibIntl_DIR "${PREBUILT_INSTALL_PATH}/lib/cmake")
find_package(LibIntl)
set(fmt_DIR "${PREBUILT_INSTALL_PATH}/lib/cmake/fmt")
find_package(fmt)

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
add_subdirectory(fcitx5)
add_subdirectory(deps)

add_subdirectory(logging)

include_directories(
    fcitx5-webview/include
    fcitx5-webview/webview
    "${HOMEBREW_PATH}/include" # nlohmann-json
)
add_subdirectory(macosfrontend)
add_subdirectory(macosnotifications)

add_subdirectory(src)
add_subdirectory(dmg)

option(BUILD_PREVIEW "" OFF)
add_subdirectory(fcitx5-webview)
