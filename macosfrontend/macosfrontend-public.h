#pragma once

#include <array>
#include <objc/objc.h>

// Identical to fcitx::ICUUID. Replicated for Swift interop.
typedef std::array<uint8_t, 16> ICUUID;

// Though being UInt, 32b is enough for modifiers
std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease) noexcept;

ICUUID create_input_context(const char *appId, id client) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid) noexcept;
std::string focus_out(ICUUID uuid) noexcept;
