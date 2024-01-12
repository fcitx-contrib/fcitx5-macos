#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include "fcitx-swift.h"

typedef uint64_t Cookie;

void start_fcitx_thread() noexcept;
void stop_fcitx_thread() noexcept;

// Though being UInt, 32b is enough for modifiers
bool process_key(Cookie cookie, uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode, bool isRelease) noexcept;

Cookie create_input_context(const char *appId) noexcept;
void destroy_input_context(Cookie) noexcept;
void focus_in(Cookie) noexcept;
void focus_out(Cookie) noexcept;

#endif
