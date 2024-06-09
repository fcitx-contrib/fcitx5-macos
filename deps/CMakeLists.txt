add_library(SwiftyJSON STATIC "${CMAKE_CURRENT_SOURCE_DIR}/SwiftyJSON/Source/SwiftyJSON/SwiftyJSON.swift")
set_target_properties(SwiftyJSON PROPERTIES Swift_MODULE_NAME SwiftyJSON)
target_include_directories(SwiftyJSON PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/SwiftyJSON/Source/SwiftyJSON")

file(GLOB ALERT_TOAST_FILES CONFIGURE_DEPENDS AlertToast/src/*.swift)
add_library(AlertToast STATIC ${ALERT_TOAST_FILES})
set_target_properties(AlertToast PROPERTIES Swift_MODULE_NAME AlertToast)
