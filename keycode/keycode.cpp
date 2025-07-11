#include "keycode.h"
#include <cstring>

static struct {
    uint16_t osxKeycode;
    fcitx::KeySym sym;
} sym_mappings[] = {
    // modifiers
    {OSX_VK_CONTROL_L, FcitxKey_Control_L},
    {OSX_VK_CONTROL_R, FcitxKey_Control_R},
    {OSX_VK_SHIFT_L, FcitxKey_Shift_L},
    {OSX_VK_SHIFT_R, FcitxKey_Shift_R},
    {OSX_VK_CAPSLOCK, FcitxKey_Caps_Lock},
    {OSX_VK_OPTION_L, FcitxKey_Alt_L},
    {OSX_VK_OPTION_R, FcitxKey_Alt_R},
    {OSX_VK_COMMAND_L, FcitxKey_Super_L},
    {OSX_VK_COMMAND_R, FcitxKey_Super_R},

    // keypad
    {OSX_VK_KEYPAD_0, FcitxKey_KP_0},
    {OSX_VK_KEYPAD_1, FcitxKey_KP_1},
    {OSX_VK_KEYPAD_2, FcitxKey_KP_2},
    {OSX_VK_KEYPAD_3, FcitxKey_KP_3},
    {OSX_VK_KEYPAD_4, FcitxKey_KP_4},
    {OSX_VK_KEYPAD_5, FcitxKey_KP_5},
    {OSX_VK_KEYPAD_6, FcitxKey_KP_6},
    {OSX_VK_KEYPAD_7, FcitxKey_KP_7},
    {OSX_VK_KEYPAD_8, FcitxKey_KP_8},
    {OSX_VK_KEYPAD_9, FcitxKey_KP_9},
    {OSX_VK_KEYPAD_COMMA, FcitxKey_KP_Separator},
    {OSX_VK_KEYPAD_DOT, FcitxKey_KP_Decimal},
    {OSX_VK_KEYPAD_EQUAL, FcitxKey_KP_Equal},
    {OSX_VK_KEYPAD_MINUS, FcitxKey_KP_Subtract},
    {OSX_VK_KEYPAD_MULTIPLY, FcitxKey_KP_Multiply},
    {OSX_VK_KEYPAD_PLUS, FcitxKey_KP_Add},
    {OSX_VK_KEYPAD_SLASH, FcitxKey_KP_Divide},

    // special
    {OSX_VK_DELETE, FcitxKey_BackSpace},
    {OSX_VK_ENTER, FcitxKey_KP_Enter},
    {OSX_VK_RETURN, FcitxKey_Return},
    {OSX_VK_SPACE, FcitxKey_space},
    {OSX_VK_TAB, FcitxKey_Tab},
    {OSX_VK_ESCAPE, FcitxKey_Escape},
    {OSX_VK_PC_DEL, FcitxKey_Delete},
    {OSX_VK_PC_INSERT, FcitxKey_Insert},
    {OSX_VK_PAGEUP, FcitxKey_Page_Up},
    {OSX_VK_PAGEDOWN, FcitxKey_Page_Down},
    {OSX_VK_HOME, FcitxKey_Home},
    {OSX_VK_END, FcitxKey_End},

    // arrow keys
    {OSX_VK_CURSOR_UP, FcitxKey_Up},
    {OSX_VK_CURSOR_DOWN, FcitxKey_Down},
    {OSX_VK_CURSOR_LEFT, FcitxKey_Left},
    {OSX_VK_CURSOR_RIGHT, FcitxKey_Right},

    // function keys
    {OSX_VK_F1, FcitxKey_F1},
    {OSX_VK_F2, FcitxKey_F2},
    {OSX_VK_F3, FcitxKey_F3},
    {OSX_VK_F4, FcitxKey_F4},
    {OSX_VK_F5, FcitxKey_F5},
    {OSX_VK_F6, FcitxKey_F6},
    {OSX_VK_F7, FcitxKey_F7},
    {OSX_VK_F8, FcitxKey_F8},
    {OSX_VK_F9, FcitxKey_F9},
    {OSX_VK_F10, FcitxKey_F10},
    {OSX_VK_F11, FcitxKey_F11},
    {OSX_VK_F12, FcitxKey_F12},
};

static struct {
    uint16_t osxKeycode;
    uint16_t linuxKeycode;
} code_mappings[] = {
    // alphabet
    {OSX_VK_A, 30},
    {OSX_VK_B, 48},
    {OSX_VK_C, 46},
    {OSX_VK_D, 32},
    {OSX_VK_E, 18},
    {OSX_VK_F, 33},
    {OSX_VK_G, 34},
    {OSX_VK_H, 35},
    {OSX_VK_I, 23},
    {OSX_VK_J, 36},
    {OSX_VK_K, 37},
    {OSX_VK_L, 38},
    {OSX_VK_M, 50},
    {OSX_VK_N, 49},
    {OSX_VK_O, 24},
    {OSX_VK_P, 25},
    {OSX_VK_Q, 16},
    {OSX_VK_R, 19},
    {OSX_VK_S, 31},
    {OSX_VK_T, 20},
    {OSX_VK_U, 22},
    {OSX_VK_V, 47},
    {OSX_VK_W, 17},
    {OSX_VK_X, 45},
    {OSX_VK_Y, 21},
    {OSX_VK_Z, 44},

    // number
    {OSX_VK_KEY_0, 11},
    {OSX_VK_KEY_1, 2},
    {OSX_VK_KEY_2, 3},
    {OSX_VK_KEY_3, 4},
    {OSX_VK_KEY_4, 5},
    {OSX_VK_KEY_5, 6},
    {OSX_VK_KEY_6, 7},
    {OSX_VK_KEY_7, 8},
    {OSX_VK_KEY_8, 9},
    {OSX_VK_KEY_9, 10},

    // symbol
    {OSX_VK_BACKQUOTE, 41},
    {OSX_VK_BACKSLASH, 43},
    {OSX_VK_BRACKET_LEFT, 26},
    {OSX_VK_BRACKET_RIGHT, 27},
    {OSX_VK_COMMA, 51},
    {OSX_VK_DOT, 52},
    {OSX_VK_EQUAL, 13},
    {OSX_VK_MINUS, 12},
    {OSX_VK_QUOTE, 40},
    {OSX_VK_SEMICOLON, 39},
    {OSX_VK_SLASH, 53},

    // keypad
    {OSX_VK_KEYPAD_0, 82},
    {OSX_VK_KEYPAD_1, 79},
    {OSX_VK_KEYPAD_2, 80},
    {OSX_VK_KEYPAD_3, 81},
    {OSX_VK_KEYPAD_4, 75},
    {OSX_VK_KEYPAD_5, 76},
    {OSX_VK_KEYPAD_6, 77},
    {OSX_VK_KEYPAD_7, 71},
    {OSX_VK_KEYPAD_8, 72},
    {OSX_VK_KEYPAD_9, 73},
    // {OSX_VK_KEYPAD_CLEAR, }, XXX: not sure map to what
    {OSX_VK_KEYPAD_COMMA, 121},
    {OSX_VK_KEYPAD_DOT, 83},
    {OSX_VK_KEYPAD_EQUAL, 117},
    {OSX_VK_KEYPAD_MINUS, 74},
    {OSX_VK_KEYPAD_MULTIPLY, 55},
    {OSX_VK_KEYPAD_PLUS, 78},
    {OSX_VK_KEYPAD_SLASH, 98},

    // special
    {OSX_VK_DELETE, 14},
    {OSX_VK_ENTER, 96},
    // {OSX_VK_ENTER_POWERBOOK, }, XXX: not sure map to what
    {OSX_VK_ESCAPE, 1},
    {OSX_VK_FORWARD_DELETE, 111},
    // {OSX_VK_HELP, }, XXX: not sure map to what
    {OSX_VK_RETURN, 28},
    {OSX_VK_SPACE, 57},
    {OSX_VK_TAB, 15},

    // function
    {OSX_VK_F1, 59},
    {OSX_VK_F2, 60},
    {OSX_VK_F3, 61},
    {OSX_VK_F4, 62},
    {OSX_VK_F5, 63},
    {OSX_VK_F6, 64},
    {OSX_VK_F7, 65},
    {OSX_VK_F8, 66},
    {OSX_VK_F9, 67},
    {OSX_VK_F10, 68},
    {OSX_VK_F11, 87},
    {OSX_VK_F12, 88},

    // cursor
    {OSX_VK_CURSOR_UP, 103},
    {OSX_VK_CURSOR_DOWN, 108},
    {OSX_VK_CURSOR_LEFT, 105},
    {OSX_VK_CURSOR_RIGHT, 106},

    {OSX_VK_PAGEUP, 104},
    {OSX_VK_PAGEDOWN, 109},
    {OSX_VK_HOME, 102},
    {OSX_VK_END, 107},

    // modifiers
    {OSX_VK_CAPSLOCK, 58},
    {OSX_VK_COMMAND_L, 125},
    {OSX_VK_COMMAND_R, 126},
    {OSX_VK_CONTROL_L, 29},
    {OSX_VK_CONTROL_R, 97},
    {OSX_VK_FN, 0x1d0},
    {OSX_VK_OPTION_L, 56},
    {OSX_VK_OPTION_R, 100},
    {OSX_VK_SHIFT_L, 42},
    {OSX_VK_SHIFT_R, 54},
};

static struct {
    uint16_t osxKeycode;
    char asciiChar;
    char shiftedAsciiChar;
} char_mappings[] = {
    // alphabet
    {OSX_VK_A, 'a', 'A'},
    {OSX_VK_B, 'b', 'B'},
    {OSX_VK_C, 'c', 'C'},
    {OSX_VK_D, 'd', 'D'},
    {OSX_VK_E, 'e', 'E'},
    {OSX_VK_F, 'f', 'F'},
    {OSX_VK_G, 'g', 'G'},
    {OSX_VK_H, 'h', 'H'},
    {OSX_VK_I, 'i', 'I'},
    {OSX_VK_J, 'j', 'J'},
    {OSX_VK_K, 'k', 'K'},
    {OSX_VK_L, 'l', 'L'},
    {OSX_VK_M, 'm', 'M'},
    {OSX_VK_N, 'n', 'N'},
    {OSX_VK_O, 'o', 'O'},
    {OSX_VK_P, 'p', 'P'},
    {OSX_VK_Q, 'q', 'Q'},
    {OSX_VK_R, 'r', 'R'},
    {OSX_VK_S, 's', 'S'},
    {OSX_VK_T, 't', 'T'},
    {OSX_VK_U, 'u', 'U'},
    {OSX_VK_V, 'v', 'V'},
    {OSX_VK_W, 'w', 'W'},
    {OSX_VK_X, 'x', 'X'},
    {OSX_VK_Y, 'y', 'Y'},
    {OSX_VK_Z, 'z', 'Z'},

    // number row with shift mappings
    {OSX_VK_KEY_0, '0', ')'},
    {OSX_VK_KEY_1, '1', '!'},
    {OSX_VK_KEY_2, '2', '@'},
    {OSX_VK_KEY_3, '3', '#'},
    {OSX_VK_KEY_4, '4', '$'},
    {OSX_VK_KEY_5, '5', '%'},
    {OSX_VK_KEY_6, '6', '^'},
    {OSX_VK_KEY_7, '7', '&'},
    {OSX_VK_KEY_8, '8', '*'},
    {OSX_VK_KEY_9, '9', '('},

    // symbols with shift
    {OSX_VK_BACKQUOTE, '`', '~'},
    {OSX_VK_BACKSLASH, '\\', '|'},
    {OSX_VK_BRACKET_LEFT, '[', '{'},
    {OSX_VK_BRACKET_RIGHT, ']', '}'},
    {OSX_VK_COMMA, ',', '<'},
    {OSX_VK_DOT, '.', '>'},
    {OSX_VK_EQUAL, '=', '+'},
    {OSX_VK_MINUS, '-', '_'},
    {OSX_VK_QUOTE, '\'', '"'},
    {OSX_VK_SEMICOLON, ';', ':'},
    {OSX_VK_SLASH, '/', '?'},
};

static struct {
    fcitx::KeySym sym;
    uint16_t osxFunctionKey;
} function_key_mappings[] = {
    {FcitxKey_Up, NSUpArrowFunctionKey},
    {FcitxKey_Down, NSDownArrowFunctionKey},
    {FcitxKey_Left, NSLeftArrowFunctionKey},
    {FcitxKey_Right,NSRightArrowFunctionKey},
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
    {OSX_MODIFIER_CAPSLOCK, fcitx::KeyState::CapsLock},
    {OSX_MODIFIER_SHIFT, fcitx::KeyState::Shift},
    {OSX_MODIFIER_CONTROL, fcitx::KeyState::Ctrl},
    {OSX_MODIFIER_OPTION, fcitx::KeyState::Alt},
    {OSX_MODIFIER_COMMAND, fcitx::KeyState::Super},
};

fcitx::KeySym osx_unicode_to_fcitx_keysym(uint32_t unicode,
                                          uint32_t osxModifiers,
                                          uint16_t osxKeycode) {
    for (const auto &pair : sym_mappings) {
        if (pair.osxKeycode == osxKeycode) {
            return pair.sym;
        }
    }
    // macOS sends special unicode for Alt+(Shift+) non-whitespace key thus can't match any configured hotkey in fcitx.
    // So we revert unicode to ascii, which doesn't change the committing special char behavior if rejected by fcitx.
    if ((osxModifiers & ~OSX_MODIFIER_SHIFT) == OSX_MODIFIER_OPTION) {
        for (const auto &pair : char_mappings) {
            if (pair.osxKeycode == osxKeycode) {
                unicode = (osxModifiers & OSX_MODIFIER_SHIFT) ? pair.shiftedAsciiChar : pair.asciiChar;
                break;
            }
        }
    }
    // Send capital keysym when shift is pressed (bug #101)
    // This is for Squirrel compatibility:
    // Squirrel recognizes Control+Shift+F and Control+Shift+0
    // but not Control+Shift+f and Control+Shift+parenright
    else if ((unicode >= 'a') && (unicode <= 'z') &&
        (osxModifiers & OSX_MODIFIER_SHIFT)) {
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
