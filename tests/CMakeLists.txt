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

# CustomPhrase .plist parser
add_executable(xml-parser testxmlparser.swift
    ${PROJECT_SOURCE_DIR}/src/config/xmlparser.swift
)
add_test(NAME xml-parser COMMAND xml-parser "${PROJECT_SOURCE_DIR}/tests/customphrase.plist")

add_executable(key-cpp testkey.cpp)
target_link_libraries(key-cpp Keycode)
add_test(NAME key-cpp COMMAND key-cpp)

add_executable(key-swift testkey.swift
    ${PROJECT_SOURCE_DIR}/src/config/keycode.swift
    ${PROJECT_SOURCE_DIR}/src/config/keyrecorder.swift
)
target_compile_options(key-swift PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)
target_link_libraries(key-swift Keycode)
add_test(NAME key-swift COMMAND key-swift)
