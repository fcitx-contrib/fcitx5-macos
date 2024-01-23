add_executable(Fcitx5
  MACOSX_BUNDLE
  server.swift
  controller.swift
  config/menu.swift
  config/about.swift
  fcitx.cpp
)

add_dependencies(Fcitx5 macosfrontend macosnotifications)

target_include_directories(Fcitx5 PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")
target_include_directories(Fcitx5 PRIVATE
  "${PROJECT_SOURCE_DIR}/fcitx5/src/im/keyboard"
  "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase/"
  "${CMAKE_CURRENT_BINARY_DIR}/../fcitx5"
)

target_link_libraries(Fcitx5
  "-Xlinker -rpath -Xlinker '${CMAKE_INSTALL_PREFIX}/lib'"
  SwiftFrontend
  SwiftNotify
  Fcitx5::Core
  keyboard
  macosfrontend
  macosnotifications
  WebviewCandidateWindow
)

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents")

set(BINARY_LIB_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/lib")
set(BINARY_MODULE_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

add_custom_command(TARGET Fcitx5 POST_BUILD
  COMMAND rm -f "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents/Macos/Fcitx5.d"
)

install(TARGETS Fcitx5
  BUNDLE DESTINATION "${APP_INSTALL_PATH}"
)
