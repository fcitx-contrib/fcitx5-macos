# Config and Option
add_executable(config-swift testconfig.swift
    ${PROJECT_SOURCE_DIR}/src/config/optionmodels.swift
    ${PROJECT_SOURCE_DIR}/src/config/config.swift
)
target_include_directories(config-swift PRIVATE "${PROJECT_SOURCE_DIR}/deps/SwiftyJSON/Source/SwiftyJSON")
target_link_libraries(config-swift Fcitx5Lib ${SWIFT_LIBS})
add_test(NAME config-swift COMMAND config-swift)

add_executable(config-cpp testconfig.cpp)
target_link_libraries(config-cpp Fcitx5Lib ${SWIFT_LIBS})
add_test(NAME config-cpp COMMAND config-cpp)
