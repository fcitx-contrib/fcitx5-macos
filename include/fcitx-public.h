#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include "fcitx-swift.h"

typedef uint64_t Cookie;

void start_fcitx_thread();

// Though being UInt, 32b is enough for modifiers
bool process_key(Cookie cookie, uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode, bool isRelease);

Cookie create_input_context(const char *appId);
void destroy_input_context(Cookie);
void focus_in(Cookie);
void focus_out(Cookie);

#endif
