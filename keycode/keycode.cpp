#include "keycode.h"
#include <cstring>

static struct {
    uint16_t osxKeycode;
    fcitx::KeySym sym;
} sym_mappings[] = {
    // modifiers
    {kVK_Control, FcitxKey_Control_L},
    {kVK_RightControl, FcitxKey_Control_R},
    {kVK_Shift, FcitxKey_Shift_L},
    {kVK_RightShift, FcitxKey_Shift_R},
    {kVK_CapsLock, FcitxKey_Caps_Lock},
    {kVK_Option, FcitxKey_Alt_L},
    {kVK_RightOption, FcitxKey_Alt_R},
    {kVK_Command, FcitxKey_Super_L},
    {kVK_RightCommand, FcitxKey_Super_R},

    // keypad
    {kVK_ANSI_Keypad0, FcitxKey_KP_0},
    {kVK_ANSI_Keypad1, FcitxKey_KP_1},
    {kVK_ANSI_Keypad2, FcitxKey_KP_2},
    {kVK_ANSI_Keypad3, FcitxKey_KP_3},
    {kVK_ANSI_Keypad4, FcitxKey_KP_4},
    {kVK_ANSI_Keypad5, FcitxKey_KP_5},
    {kVK_ANSI_Keypad6, FcitxKey_KP_6},
    {kVK_ANSI_Keypad7, FcitxKey_KP_7},
    {kVK_ANSI_Keypad8, FcitxKey_KP_8},
    {kVK_ANSI_Keypad9, FcitxKey_KP_9},
    {kVK_JIS_KeypadComma, FcitxKey_KP_Separator},
    {kVK_ANSI_KeypadDecimal, FcitxKey_KP_Decimal},
    {kVK_ANSI_KeypadEquals, FcitxKey_KP_Equal},
    {kVK_ANSI_KeypadMinus, FcitxKey_KP_Subtract},
    {kVK_ANSI_KeypadMultiply, FcitxKey_KP_Multiply},
    {kVK_ANSI_KeypadPlus, FcitxKey_KP_Add},
    {kVK_ANSI_KeypadDivide, FcitxKey_KP_Divide},

    // special
    {kVK_Delete, FcitxKey_BackSpace},
    {kVK_ANSI_KeypadEnter, FcitxKey_KP_Enter},
    {kVK_Return, FcitxKey_Return},
    {kVK_Space, FcitxKey_space},
    {kVK_Tab, FcitxKey_Tab},
    {kVK_Escape, FcitxKey_Escape},
    {kVK_ForwardDelete, FcitxKey_Delete},
    {kVK_Help, FcitxKey_Insert},
    {kVK_PageUp, FcitxKey_Page_Up},
    {kVK_PageDown, FcitxKey_Page_Down},
    {kVK_Home, FcitxKey_Home},
    {kVK_End, FcitxKey_End},
    {kVK_ANSI_KeypadClear, FcitxKey_Num_Lock},
    {kVK_F13, FcitxKey_Print},
    {kVK_F14, FcitxKey_Scroll_Lock},
    {kVK_F15, FcitxKey_Pause},

    // arrow keys
    {kVK_UpArrow, FcitxKey_Up},
    {kVK_DownArrow, FcitxKey_Down},
    {kVK_LeftArrow, FcitxKey_Left},
    {kVK_RightArrow, FcitxKey_Right},

    // function keys
    {kVK_F1, FcitxKey_F1},
    {kVK_F2, FcitxKey_F2},
    {kVK_F3, FcitxKey_F3},
    {kVK_F4, FcitxKey_F4},
    {kVK_F5, FcitxKey_F5},
    {kVK_F6, FcitxKey_F6},
    {kVK_F7, FcitxKey_F7},
    {kVK_F8, FcitxKey_F8},
    {kVK_F9, FcitxKey_F9},
    {kVK_F10, FcitxKey_F10},
    {kVK_F11, FcitxKey_F11},
    {kVK_F12, FcitxKey_F12},
};

static struct {
    uint16_t osxKeycode;
    uint16_t linuxKeycode;
} code_mappings[] = {
    // alphabet
    {kVK_ANSI_A, 30},
    {kVK_ANSI_B, 48},
    {kVK_ANSI_C, 46},
    {kVK_ANSI_D, 32},
    {kVK_ANSI_E, 18},
    {kVK_ANSI_F, 33},
    {kVK_ANSI_G, 34},
    {kVK_ANSI_H, 35},
    {kVK_ANSI_I, 23},
    {kVK_ANSI_J, 36},
    {kVK_ANSI_K, 37},
    {kVK_ANSI_L, 38},
    {kVK_ANSI_M, 50},
    {kVK_ANSI_N, 49},
    {kVK_ANSI_O, 24},
    {kVK_ANSI_P, 25},
    {kVK_ANSI_Q, 16},
    {kVK_ANSI_R, 19},
    {kVK_ANSI_S, 31},
    {kVK_ANSI_T, 20},
    {kVK_ANSI_U, 22},
    {kVK_ANSI_V, 47},
    {kVK_ANSI_W, 17},
    {kVK_ANSI_X, 45},
    {kVK_ANSI_Y, 21},
    {kVK_ANSI_Z, 44},

    // number
    {kVK_ANSI_0, 11},
    {kVK_ANSI_1, 2},
    {kVK_ANSI_2, 3},
    {kVK_ANSI_3, 4},
    {kVK_ANSI_4, 5},
    {kVK_ANSI_5, 6},
    {kVK_ANSI_6, 7},
    {kVK_ANSI_7, 8},
    {kVK_ANSI_8, 9},
    {kVK_ANSI_9, 10},

    // symbol
    {kVK_ANSI_Grave, 41},
    {kVK_ANSI_Backslash, 43},
    {kVK_ANSI_LeftBracket, 26},
    {kVK_ANSI_RightBracket, 27},
    {kVK_ANSI_Comma, 51},
    {kVK_ANSI_Period, 52},
    {kVK_ANSI_Equal, 13},
    {kVK_ANSI_Minus, 12},
    {kVK_ANSI_Quote, 40},
    {kVK_ANSI_Semicolon, 39},
    {kVK_ANSI_Slash, 53},

    // keypad
    {kVK_ANSI_Keypad0, 82},
    {kVK_ANSI_Keypad1, 79},
    {kVK_ANSI_Keypad2, 80},
    {kVK_ANSI_Keypad3, 81},
    {kVK_ANSI_Keypad4, 75},
    {kVK_ANSI_Keypad5, 76},
    {kVK_ANSI_Keypad6, 77},
    {kVK_ANSI_Keypad7, 71},
    {kVK_ANSI_Keypad8, 72},
    {kVK_ANSI_Keypad9, 73},
    {kVK_JIS_KeypadComma, 121},
    {kVK_ANSI_KeypadDecimal, 83},
    {kVK_ANSI_KeypadEquals, 117},
    {kVK_ANSI_KeypadMinus, 74},
    {kVK_ANSI_KeypadMultiply, 55},
    {kVK_ANSI_KeypadPlus, 78},
    {kVK_ANSI_KeypadDivide, 98},

    // special
    {kVK_Delete, 14},
    {kVK_ANSI_KeypadEnter, 96},
    {kVK_Escape, 1},
    {kVK_ForwardDelete, 111},
    {kVK_Return, 28},
    {kVK_Space, 57},
    {kVK_Tab, 15},

    // function
    {kVK_F1, 59},
    {kVK_F2, 60},
    {kVK_F3, 61},
    {kVK_F4, 62},
    {kVK_F5, 63},
    {kVK_F6, 64},
    {kVK_F7, 65},
    {kVK_F8, 66},
    {kVK_F9, 67},
    {kVK_F10, 68},
    {kVK_F11, 87},
    {kVK_F12, 88},

    // cursor
    {kVK_UpArrow, 103},
    {kVK_DownArrow, 108},
    {kVK_LeftArrow, 105},
    {kVK_RightArrow, 106},

    {kVK_PageUp, 104},
    {kVK_PageDown, 109},
    {kVK_Home, 102},
    {kVK_End, 107},

    // modifiers
    {kVK_CapsLock, 58},
    {kVK_Command, 125},
    {kVK_RightCommand, 126},
    {kVK_Control, 29},
    {kVK_RightControl, 97},
    {kVK_Function, 0x1d0},
    {kVK_Option, 56},
    {kVK_RightOption, 100},
    {kVK_Shift, 42},
    {kVK_RightShift, 54},
};

static struct {
    uint16_t osxKeycode;
    char asciiChar;
    char shiftedAsciiChar;
} char_mappings[] = {
    // alphabet
    {kVK_ANSI_A, 'a', 'A'},
    {kVK_ANSI_B, 'b', 'B'},
    {kVK_ANSI_C, 'c', 'C'},
    {kVK_ANSI_D, 'd', 'D'},
    {kVK_ANSI_E, 'e', 'E'},
    {kVK_ANSI_F, 'f', 'F'},
    {kVK_ANSI_G, 'g', 'G'},
    {kVK_ANSI_H, 'h', 'H'},
    {kVK_ANSI_I, 'i', 'I'},
    {kVK_ANSI_J, 'j', 'J'},
    {kVK_ANSI_K, 'k', 'K'},
    {kVK_ANSI_L, 'l', 'L'},
    {kVK_ANSI_M, 'm', 'M'},
    {kVK_ANSI_N, 'n', 'N'},
    {kVK_ANSI_O, 'o', 'O'},
    {kVK_ANSI_P, 'p', 'P'},
    {kVK_ANSI_Q, 'q', 'Q'},
    {kVK_ANSI_R, 'r', 'R'},
    {kVK_ANSI_S, 's', 'S'},
    {kVK_ANSI_T, 't', 'T'},
    {kVK_ANSI_U, 'u', 'U'},
    {kVK_ANSI_V, 'v', 'V'},
    {kVK_ANSI_W, 'w', 'W'},
    {kVK_ANSI_X, 'x', 'X'},
    {kVK_ANSI_Y, 'y', 'Y'},
    {kVK_ANSI_Z, 'z', 'Z'},

    // number row with shift mappings
    {kVK_ANSI_0, '0', ')'},
    {kVK_ANSI_1, '1', '!'},
    {kVK_ANSI_2, '2', '@'},
    {kVK_ANSI_3, '3', '#'},
    {kVK_ANSI_4, '4', '$'},
    {kVK_ANSI_5, '5', '%'},
    {kVK_ANSI_6, '6', '^'},
    {kVK_ANSI_7, '7', '&'},
    {kVK_ANSI_8, '8', '*'},
    {kVK_ANSI_9, '9', '('},

    // symbols with shift
    {kVK_ANSI_Grave, '`', '~'},
    {kVK_ANSI_Backslash, '\\', '|'},
    {kVK_ANSI_LeftBracket, '[', '{'},
    {kVK_ANSI_RightBracket, ']', '}'},
    {kVK_ANSI_Comma, ',', '<'},
    {kVK_ANSI_Period, '.', '>'},
    {kVK_ANSI_Equal, '=', '+'},
    {kVK_ANSI_Minus, '-', '_'},
    {kVK_ANSI_Quote, '\'', '"'},
    {kVK_ANSI_Semicolon, ';', ':'},
    {kVK_ANSI_Slash, '/', '?'},
};

static struct {
    fcitx::KeySym sym;
    uint16_t osxFunctionKey;
} function_key_mappings[] = {
    {FcitxKey_Up, NSUpArrowFunctionKey},
    {FcitxKey_Down, NSDownArrowFunctionKey},
    {FcitxKey_Left, NSLeftArrowFunctionKey},
    {FcitxKey_Right, NSRightArrowFunctionKey},
    {FcitxKey_F1, NSF1FunctionKey},
    {FcitxKey_F2, NSF2FunctionKey},
    {FcitxKey_F3, NSF3FunctionKey},
    {FcitxKey_F4, NSF4FunctionKey},
    {FcitxKey_F5, NSF5FunctionKey},
    {FcitxKey_F6, NSF6FunctionKey},
    {FcitxKey_F7, NSF7FunctionKey},
    {FcitxKey_F8, NSF8FunctionKey},
    {FcitxKey_F9, NSF9FunctionKey},
    {FcitxKey_F10, NSF10FunctionKey},
    {FcitxKey_F11, NSF11FunctionKey},
    {FcitxKey_F12, NSF12FunctionKey},
    {FcitxKey_Home, NSHomeFunctionKey},
    {FcitxKey_End, NSEndFunctionKey},
    {FcitxKey_Page_Up, NSPageUpFunctionKey},
    {FcitxKey_Page_Down, NSPageDownFunctionKey},
};

static struct {
    uint32_t osxModifier;
    fcitx::KeyState fcitxModifier;
} modifier_mappings[] = {
    {NSEventModifierFlagCapsLock, fcitx::KeyState::CapsLock},
    {NSEventModifierFlagShift, fcitx::KeyState::Shift},
    {NSEventModifierFlagControl, fcitx::KeyState::Ctrl},
    {NSEventModifierFlagOption, fcitx::KeyState::Alt},
    {NSEventModifierFlagCommand, fcitx::KeyState::Super},
};

fcitx::KeySym osx_unicode_to_fcitx_keysym(uint32_t unicode,
                                          uint32_t osxModifiers,
                                          uint16_t osxKeycode) {
    for (const auto &pair : sym_mappings) {
        if (pair.osxKeycode == osxKeycode) {
            return pair.sym;
        }
    }
    // macOS sends special unicode for Alt+(Shift+) non-whitespace key thus
    // can't match any configured hotkey in fcitx. So we revert unicode to
    // ascii, which doesn't change the committing special char behavior if
    // rejected by fcitx.
    if ((osxModifiers & ~NSEventModifierFlagShift) ==
        NSEventModifierFlagOption) {
        for (const auto &pair : char_mappings) {
            if (pair.osxKeycode == osxKeycode) {
                unicode = (osxModifiers & NSEventModifierFlagShift)
                              ? pair.shiftedAsciiChar
                              : pair.asciiChar;
                break;
            }
        }
    }
    // Send capital keysym when shift is pressed (bug #101)
    // This is for Squirrel compatibility:
    // Squirrel recognizes Control+Shift+F and Control+Shift+0
    // but not Control+Shift+f and Control+Shift+parenright
    else if ((unicode >= 'a') && (unicode <= 'z') &&
             (osxModifiers & NSEventModifierFlagShift)) {
        unicode = unicode - 'a' + 'A';
    }
    return fcitx::Key::keySymFromUnicode(unicode);
}

uint16_t osx_keycode_to_fcitx_keycode(uint16_t osxKeycode) {
    for (const auto &pair : code_mappings) {
        if (pair.osxKeycode == osxKeycode) {
            return pair.linuxKeycode + 8 /* evdev offset */;
        }
    }
    return 0;
}

uint16_t fcitx_keysym_to_osx_keycode(fcitx::KeySym sym) {
    for (const auto &pair : sym_mappings) {
        if (pair.sym == sym) {
            return pair.osxKeycode;
        }
    }
    return 0;
}

fcitx::KeyStates osx_modifiers_to_fcitx_keystates(unsigned int osxModifiers) {
    fcitx::KeyStates ret{};
    for (const auto &pair : modifier_mappings) {
        if (osxModifiers & pair.osxModifier) {
            ret |= pair.fcitxModifier;
        }
    }
    return ret;
}

std::string fcitx_keysym_to_osx_keysym(fcitx::KeySym keySym) {
    // No way to distinguish with normal number keys for shortcut in menu.
    if (fcitx::Key{keySym}.isKeyPad()) {
        return "";
    }
    // keySymToString returns grave for `, which will be used as G by macOS.
    auto sym = fcitx::Key::keySymToUTF8(keySym);
    // Normalized fcitx key like Control+D will show and be counted as
    // Control+Shift+D in macOS menu, so we lower it.
    if (sym.size() == 1 && std::isupper(sym[0])) {
        sym[0] = std::tolower(sym[0]);
    }
    return sym;
}

uint16_t fcitx_keysym_to_osx_function_key(fcitx::KeySym keySym) {
    for (const auto &pair : function_key_mappings) {
        if (pair.sym == keySym) {
            return pair.osxFunctionKey;
        }
    }
    return 0;
}

uint32_t fcitx_keystates_to_osx_modifiers(fcitx::KeyStates ks) {
    uint32_t ret{};
    for (const auto &pair : modifier_mappings) {
        if (ks & pair.fcitxModifier) {
            ret |= pair.osxModifier;
        }
    }
    return ret;
}

std::string fcitx_string_to_osx_keysym(const char *s) noexcept {
    fcitx::Key key{s};
    return fcitx_keysym_to_osx_keysym(key.sym());
}

uint32_t fcitx_string_to_osx_modifiers(const char *s) noexcept {
    fcitx::Key key{s};
    return fcitx_keystates_to_osx_modifiers(key.states());
}

uint16_t fcitx_string_to_osx_keycode(const char *s) noexcept {
    fcitx::Key key{s};
    return fcitx_keysym_to_osx_keycode(key.sym());
}

fcitx::Key osx_key_to_fcitx_key(uint32_t unicode, uint32_t modifiers,
                                uint16_t code) noexcept {
    return fcitx::Key{
        osx_unicode_to_fcitx_keysym(unicode, modifiers, code),
        osx_modifiers_to_fcitx_keystates(modifiers),
        osx_keycode_to_fcitx_keycode(code),
    };
}

std::string osx_key_to_fcitx_string(uint32_t unicode, uint32_t modifiers,
                                    uint16_t code) noexcept {
    // Convert captured shortcut to the format that fcitx configuration accepts.
    // Use normalize so that we get Control+0, Control+parenright, Control+D and
    // Control+Shift+D. Other forms either don't work or work the same way.
    return osx_key_to_fcitx_key(unicode, modifiers, code)
        .normalize()
        .toString();
}
