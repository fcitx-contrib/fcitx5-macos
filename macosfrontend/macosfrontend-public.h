#pragma once

#include <objc/objc.h>
#include "fcitx-public.h"

// Though being UInt, 32b is enough for modifiers
std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease) noexcept;
std::string osx_key_to_fcitx_string(uint32_t unicode, uint32_t modifiers,
                                    uint16_t code) noexcept;

ICUUID create_input_context(const char *appId, id client) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid) noexcept;
void focus_out(ICUUID uuid) noexcept;
