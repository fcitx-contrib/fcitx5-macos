add_library(f5mtest STATIC
    "${PROJECT_SOURCE_DIR}/src/fcitx.cpp"
    "${PROJECT_SOURCE_DIR}/src/config/config.cpp"
)
target_include_directories(f5mtest PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/im/keyboard"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase/"
    "${PROJECT_BINARY_DIR}/fcitx5"
)
target_link_libraries(f5mtest PUBLIC
    "-Xlinker -rpath -Xlinker '${CMAKE_INSTALL_PREFIX}/lib'"
    Fcitx5::Core keyboard macosnotifications macosfrontend WebviewCandidateWindow
)
set(SWIFT_LIBS SwiftyJSON Logging SwiftNotify SwiftFrontend)

# Config and Option
add_executable(config-swift testconfig.swift
    ${PROJECT_SOURCE_DIR}/src/config/optionmodels.swift
    ${PROJECT_SOURCE_DIR}/src/config/config.swift
)
target_include_directories(config-swift PRIVATE "${PROJECT_SOURCE_DIR}/deps/SwiftyJSON/Source/SwiftyJSON")
target_link_libraries(config-swift f5mtest ${SWIFT_LIBS})
add_test(NAME config-swift COMMAND config-swift)

add_executable(config-cpp testconfig.cpp)
target_link_libraries(config-cpp f5mtest ${SWIFT_LIBS})
add_test(NAME config-cpp COMMAND config-cpp)
