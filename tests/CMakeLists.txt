# Config and Option
add_executable(ConfigSwift testconfig.swift
    ${PROJECT_SOURCE_DIR}/src/color.swift
    ${PROJECT_SOURCE_DIR}/src/config/optionmodels.swift
    ${PROJECT_SOURCE_DIR}/src/config/config.swift
    ${PROJECT_SOURCE_DIR}/src/config/util.swift
)
target_compile_options(ConfigSwift PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)
target_link_libraries(ConfigSwift Fcitx5Objs Logging SwiftyJSON SwiftFrontend)
add_test(NAME ConfigSwift COMMAND ConfigSwift)

add_executable(config-cpp testconfig.cpp)
target_link_libraries(config-cpp Fcitx5Objs SwiftFrontend)
fcitx5_import_addons(config-cpp
    REGISTRY_VARNAME getStaticAddon
    ADDONS keyboard
)
add_test(NAME config-cpp COMMAND config-cpp)

# CustomPhrase .plist parser
add_executable(XmlParser testxmlparser.swift
    ${PROJECT_SOURCE_DIR}/src/config/xmlparser.swift
)
add_test(NAME XmlParser COMMAND XmlParser "${PROJECT_SOURCE_DIR}/tests/customphrase.plist")

add_executable(key-cpp testkey.cpp)
target_link_libraries(key-cpp Keycode)
add_test(NAME key-cpp COMMAND key-cpp)

add_executable(KeySwift testkey.swift
    ${PROJECT_SOURCE_DIR}/src/config/keycode.swift
    ${PROJECT_SOURCE_DIR}/src/config/keyrecorder.swift
)
target_compile_options(KeySwift PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)
target_link_libraries(KeySwift Keycode)
add_test(NAME KeySwift COMMAND KeySwift)

add_executable(TagSwift testtag.swift
    ${PROJECT_SOURCE_DIR}/src/config/tag.swift
)
add_test(NAME TagSwift COMMAND TagSwift)

add_executable(ColorSwift testcolor.swift
    ${PROJECT_SOURCE_DIR}/src/color.swift
)
add_test(NAME ColorSwift COMMAND ColorSwift)
