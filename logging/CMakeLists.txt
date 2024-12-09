if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(IS_DEBUG true)
else()
    set(IS_DEBUG false)
endif()
configure_file(debug.swift.in ${CMAKE_CURRENT_SOURCE_DIR}/debug.swift @ONLY)

add_library(Logging STATIC logging.swift debug.swift)
