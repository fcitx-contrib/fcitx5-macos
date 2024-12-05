#pragma once

#include <cstdint>
#include <string>

std::string osx_key_to_fcitx_string(uint32_t unicode, uint32_t modifiers,
                                    uint16_t code) noexcept;
std::string fcitx_string_to_osx_keysym(const char *) noexcept;
uint32_t fcitx_string_to_osx_modifiers(const char *) noexcept;
uint16_t fcitx_string_to_osx_keycode(const char *) noexcept;
