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

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
// Returns a json array of strings.
std::string input_method_groups() noexcept;
// Retruns json [["id1", "name1"], ["id2", "name2"], ...].
std::string current_input_method_list() noexcept;
// Returns json
// [{"name": "group name", "inputMethods":
//   [{"name": ..., "displayName": ...}...]}...].
std::string all_input_methods() noexcept;
// uses the same format as all_input_methods
void set_input_method_groups(const char *) noexcept;
std::string input_method_list(const char *) noexcept;
void set_current_input_method_group(const char *) noexcept;
std::string get_current_input_method_group() noexcept;
void set_current_input_method(const char *) noexcept;
std::string get_current_input_method() noexcept;
std::string current_actions() noexcept;
void activate_action_by_id(int id) noexcept;

#endif
