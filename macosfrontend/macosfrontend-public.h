#pragma once

#include <array>
#include <objc/objc.h>

// Identical to fcitx::ICUUID. Replicated for Swift interop.
typedef std::array<uint8_t, 16> ICUUID;

// Though being UInt, 32b is enough for modifiers
std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease,
                        bool isPassword) noexcept;

ICUUID create_input_context(const char *appId, id client,
                            const char *accentColor) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid, bool isPassword) noexcept;
std::string commit_composition(ICUUID uuid) noexcept;
void focus_out(ICUUID uuid) noexcept;
