cmake_minimum_required(VERSION 3.27)

project(fcitx5-macos VERSION 0.1.0 LANGUAGES CXX Swift)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

include(InitializeSwift)
include(AddSwift)

set(CMAKE_CXX_STANDARD 17)

if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

if(CMAKE_OSX_ARCHITECTURES STREQUAL arm64)
    add_definitions(-target "arm64-apple-macos11")
    set(HOMEBREW_PATH "/opt/homebrew")
else()
    set(HOMEBREW_PATH "/usr/local")
endif()

set(ENV{PKG_CONFIG_PATH} "${HOMEBREW_PATH}/lib/pkgconfig:${HOMEBREW_PATH}/share/pkgconfig:${HOMEBREW_PATH}/opt/expat/lib/pkgconfig")

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

set(APP_INSTALL_PATH "/Library/Input Methods")
set(CMAKE_INSTALL_PREFIX "${APP_INSTALL_PATH}/Fcitx5.app/Contents")
# Reproducible
set(CMAKE_INSTALL_LIBDATADIR "${CMAKE_INSTALL_PREFIX}/lib")
add_subdirectory(fcitx5)

add_subdirectory(macosfrontend)
add_subdirectory(macosnotifications)

include_directories(include)
add_subdirectory(src)
add_subdirectory(dmg)
