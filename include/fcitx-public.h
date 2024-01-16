#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include <string>

typedef uint64_t Cookie;

void start_fcitx_thread() noexcept;
void stop_fcitx_thread() noexcept;
void restart_fcitx_process();

// Though being UInt, 32b is enough for modifiers
bool process_key(Cookie cookie, uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode, bool isRelease) noexcept;

Cookie create_input_context(const char *appId) noexcept;
void destroy_input_context(Cookie) noexcept;
void focus_in(Cookie) noexcept;
void focus_out(Cookie) noexcept;

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
std::string input_method_groups() noexcept;
std::string input_method_list() noexcept;
void set_current_input_method_group(const char *) noexcept;
std::string get_current_input_method_group() noexcept;
void set_current_input_method(const char *) noexcept;
std::string get_current_input_method() noexcept;

#endif
