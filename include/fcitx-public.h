#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <array>
#include <cstdint>
#include <string>

// Identical to fcitx::ICUUID. Replicated for Swift interop.
typedef std::array<uint8_t, 16> ICUUID;

void start_fcitx_thread() noexcept;
void stop_fcitx_thread() noexcept;
void restart_fcitx_thread() noexcept;

// Though being UInt, 32b is enough for modifiers
bool process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) noexcept;

ICUUID create_input_context(const char *appId) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid) noexcept;
void focus_out(ICUUID uuid) noexcept;

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
std::string input_method_groups() noexcept;
std::string input_method_list() noexcept;
void set_current_input_method_group(const char *) noexcept;
std::string get_current_input_method_group() noexcept;
void set_current_input_method(const char *) noexcept;
std::string get_current_input_method() noexcept;

#endif
