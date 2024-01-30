add_library(SwiftyJSON STATIC "${CMAKE_CURRENT_SOURCE_DIR}/SwiftyJSON/Source/SwiftyJSON/SwiftyJSON.swift")
set_target_properties(SwiftyJSON PROPERTIES Swift_MODULE_NAME SwiftyJSON)
target_include_directories(SwiftyJSON PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/SwiftyJSON/Source/SwiftyJSON")
