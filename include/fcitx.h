#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <cstdint>
#include "fcitx-swift.h"

void start_fcitx();
bool process_key(uint16_t osxKeycode, uint32_t osxKeychar, uint64_t osxModifiers);

#endif
