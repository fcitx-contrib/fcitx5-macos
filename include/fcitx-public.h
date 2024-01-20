#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include <string>

void start_fcitx_thread() noexcept;
void stop_fcitx_thread() noexcept;
void restart_fcitx_thread() noexcept;

// Though being UInt, 32b is enough for modifiers
bool process_key(uint64_t first, uint64_t second, uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode, bool isRelease) noexcept;

void create_input_context(const char *appId, uint64_t *first, uint64_t *second) noexcept;
void destroy_input_context(uint64_t first, uint64_t second) noexcept;
void focus_in(uint64_t first, uint64_t second) noexcept;
void focus_out(uint64_t first, uint64_t second) noexcept;

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
std::string input_method_groups() noexcept;
std::string input_method_list() noexcept;
void set_current_input_method_group(const char *) noexcept;
std::string get_current_input_method_group() noexcept;
void set_current_input_method(const char *) noexcept;
std::string get_current_input_method() noexcept;

#endif
