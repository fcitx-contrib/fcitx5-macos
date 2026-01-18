#pragma once

#include <Carbon/Carbon.h>
#include <fcitx-utils/key.h>
#include "keycode-public.h"

// clang-format off

// AppKit/NSEvent.h but it's Objective-C header so copy useful definitions.
#define NSEventModifierFlagCapsLock   (1 << 16)
#define NSEventModifierFlagShift      (1 << 17)
#define NSEventModifierFlagControl    (1 << 18)
#define NSEventModifierFlagOption     (1 << 19)
#define NSEventModifierFlagCommand    (1 << 20)

enum {
    NSUpArrowFunctionKey        = 0xF700,
    NSDownArrowFunctionKey      = 0xF701,
    NSLeftArrowFunctionKey      = 0xF702,
    NSRightArrowFunctionKey     = 0xF703,
    NSF1FunctionKey             = 0xF704,
    NSF2FunctionKey             = 0xF705,
    NSF3FunctionKey             = 0xF706,
    NSF4FunctionKey             = 0xF707,
    NSF5FunctionKey             = 0xF708,
    NSF6FunctionKey             = 0xF709,
    NSF7FunctionKey             = 0xF70A,
    NSF8FunctionKey             = 0xF70B,
    NSF9FunctionKey             = 0xF70C,
    NSF10FunctionKey            = 0xF70D,
    NSF11FunctionKey            = 0xF70E,
    NSF12FunctionKey            = 0xF70F,
    // Using Insert as keyEquivalent will result in ' wrongly used.
    // NSInsertFunctionKey      = 0xF727,
    // fcitx_keysym_to_osx_keysym is responsible for Delete and Backspace.
    // NSDeleteFunctionKey      = 0xF728,
    NSHomeFunctionKey           = 0xF729,
    NSEndFunctionKey            = 0xF72B,
    NSPageUpFunctionKey         = 0xF72C,
    NSPageDownFunctionKey       = 0xF72D,
};
// clang-format on

fcitx::KeySym osx_unicode_to_fcitx_keysym(uint32_t unicode,
                                          uint32_t osxModifiers,
                                          uint16_t osxKeycode);
uint16_t osx_keycode_to_fcitx_keycode(uint16_t osxKeycode);
fcitx::KeyStates osx_modifiers_to_fcitx_keystates(uint32_t osxModifiers);

fcitx::Key osx_key_to_fcitx_key(uint32_t unicode, uint32_t modifiers,
                                uint16_t code) noexcept;

// Used for showing shortcut configuration and setting shortcut for menu items.
// No need to be complete and sometimes must be inaccurate (e.g. A -> a).
std::string fcitx_keysym_to_osx_keysym(fcitx::KeySym);
uint16_t fcitx_keysym_to_osx_function_key(fcitx::KeySym);

uint16_t fcitx_keysym_to_osx_keycode(fcitx::KeySym);
uint32_t fcitx_keystates_to_osx_modifiers(fcitx::KeyStates ks);
