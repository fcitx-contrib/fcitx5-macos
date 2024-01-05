#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include "fcitx-swift.h"

void start_fcitx() noexcept;
// Though being UInt, 32b is enough for modifiers
bool process_key(uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode) noexcept;

#endif
