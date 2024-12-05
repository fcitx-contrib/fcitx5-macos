add_library(Keycode keycode.cpp)
target_include_directories(Keycode PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(Keycode Fcitx5::Utils)
