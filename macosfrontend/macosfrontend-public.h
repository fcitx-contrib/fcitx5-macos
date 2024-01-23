#pragma once

#include <objc/objc.h>
#include "fcitx-public.h"

// Though being UInt, 32b is enough for modifiers
bool process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) noexcept;

ICUUID create_input_context(const char *appId, id client) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid) noexcept;
void focus_out(ICUUID uuid) noexcept;
