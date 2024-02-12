# Config and Option
add_executable(config-swift testconfig.swift
    ${PROJECT_SOURCE_DIR}/src/config/optionmodels.swift
    ${PROJECT_SOURCE_DIR}/src/config/config.swift
)
target_link_libraries(config-swift Fcitx5Objs)
add_test(NAME config-swift COMMAND config-swift)

add_executable(config-cpp testconfig.cpp)
target_link_libraries(config-cpp Fcitx5Objs)
add_test(NAME config-cpp COMMAND config-cpp)
