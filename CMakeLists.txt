cmake_minimum_required(VERSION 4.3)

set(CMAKE_OSX_DEPLOYMENT_TARGET 13.3)
if(NOT CMAKE_OSX_ARCHITECTURES)
    execute_process(COMMAND uname -m
        OUTPUT_VARIABLE CMAKE_OSX_ARCHITECTURES
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()
set(CMAKE_Swift_COMPILER_TARGET "${CMAKE_OSX_ARCHITECTURES}-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")

# Starting from cmake 4.0, CMAKE_OSX_SYSROOT defaults to empty.
execute_process(COMMAND xcrun --sdk macosx --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# SourceKit-LSP uses the compiler path to locate sourcekitd, but fails when
# compile_commands.json contains the /usr/bin/swiftc trampoline.
if(NOT CMAKE_Swift_COMPILER OR CMAKE_Swift_COMPILER STREQUAL "/usr/bin/swiftc")
    execute_process(COMMAND xcrun -f swiftc
        OUTPUT_VARIABLE SWIFTC
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(CMAKE_Swift_COMPILER "${SWIFTC}" CACHE FILEPATH "Swift compiler" FORCE)
endif()

project(fcitx5-macos VERSION 0.4.0 LANGUAGES CXX Swift)

list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# VSCode's Swift extension only searches build/compile_commands.json to start sourcekit-lsp.
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E create_symlink
        "${CMAKE_OSX_ARCHITECTURES}/compile_commands.json"
        "${PROJECT_BINARY_DIR}/../compile_commands.json"
    COMMAND_ERROR_IS_FATAL ANY
)

# On x86 /Library/Frameworks/Mono.framework will mess up libintl.
set(CMAKE_FIND_FRAMEWORK LAST)

add_compile_options(-target "${CMAKE_Swift_COMPILER_TARGET}")
add_link_options(-target "${CMAKE_Swift_COMPILER_TARGET}")

set(CMAKE_Swift_LANGUAGE_VERSION 6)
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

# Workaround duplicated libxkbcommon.a for ECM 6.27.0 (fa26209).
add_library(XKBCommon::XKBCommon UNKNOWN IMPORTED)
set_target_properties(XKBCommon::XKBCommon PROPERTIES
    IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libxkbcommon.a"
    INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
)

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
set(FCITX_INSTALL_LOCALEDIR "${CMAKE_INSTALL_PREFIX}/share/locale")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
# Reproducible
set(CMAKE_INSTALL_LIBDATADIR "${CMAKE_INSTALL_PREFIX}/lib")

# Override iso-codes paths and xkb default rules file
set(ISOCODES_ISO639_JSON "${CMAKE_INSTALL_PREFIX}/share/iso-codes/json/iso_639-3.json")
set(XKEYBOARDCONFIG_XKBBASE "${CMAKE_INSTALL_PREFIX}/share/xkeyboard-config-2")
set(XKEYBOARDCONFIG_DATADIR "${CMAKE_INSTALL_PREFIX}/share")

execute_process(COMMAND bash -c "git describe --long | awk -F- '{print $1}'"
    OUTPUT_VARIABLE RECENT_TAG
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND bash -c "git describe --long | awk -F- '{print $2}'"
    OUTPUT_VARIABLE RECENT_COMMITS
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "Recent tag: ${RECENT_TAG}, commits since tag: ${RECENT_COMMITS}")

add_subdirectory(fcitx5)
add_subdirectory(deps)

add_subdirectory(logging)

set(WKWEBVIEW_PROTOCOL "fcitx")
set(WEBVIEW_WWW_PATH ".local/share/fcitx5/www")

include_directories(
    fcitx5-webview/include
    fcitx5-webview/webview/core/include
    "${PREBUILDER_INCLUDE_DIR}" # nlohmann-json
)

add_subdirectory(keycode)
add_subdirectory(macosfrontend)
add_subdirectory(macosnotifications)

option(BUILD_PREVIEW "" OFF)
add_subdirectory(fcitx5-webview)
add_subdirectory(webpanel)

set(BUILD_SHARED_FCITX_ADDON OFF)
include(fcitx5/src/lib/fcitx-utils/Fcitx5Macros.cmake)
add_subdirectory(fcitx5-beast)

add_subdirectory(src)

set(FCITX5_AID_TARGETS macosfrontend notifications webpanel Fcitx5Objs)
fcitx5_add_i18n_definition(
    LOCALE_INSTALL_DIR "${FCITX_INSTALL_LOCALEDIR}"
    TARGETS "${FCITX5_AID_TARGETS}"
)
foreach(AID_TARGET IN LISTS FCITX5_AID_TARGETS)
    target_compile_definitions(${AID_TARGET} PRIVATE -DFCITX_GETTEXT_DOMAIN=\"fcitx5-macos\")
endforeach()

add_subdirectory(assets)
add_subdirectory(po)

enable_testing()
add_subdirectory(tests)

add_subdirectory(appium)
