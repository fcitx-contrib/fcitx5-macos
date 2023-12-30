#include "keycode.h"
#include <cstring>

static struct {
    int osxKeycode;
    fcitx::KeySym keysym;
} mappings[] = {
    // special
    {OSX_VK_RETURN, FcitxKey_Return},
    {OSX_VK_DELETE, FcitxKey_BackSpace},
    {OSX_VK_TAB, FcitxKey_Tab},
    {OSX_VK_ESCAPE, FcitxKey_Escape},

    // arrows
    {OSX_VK_CURSOR_DOWN, FcitxKey_Down},
    {OSX_VK_CURSOR_UP, FcitxKey_Up},
    {OSX_VK_CURSOR_LEFT, FcitxKey_Left},
    {OSX_VK_CURSOR_RIGHT, FcitxKey_Right},

    // modifier keys
    {OSX_VK_SHIFT_L, FcitxKey_Shift_L},
    {OSX_VK_SHIFT_R, FcitxKey_Shift_R},
    {OSX_VK_CONTROL_L, FcitxKey_Control_L},
    {OSX_VK_CONTROL_R, FcitxKey_Control_R},
    {OSX_VK_COMMAND_L, FcitxKey_Super_L},
    {OSX_VK_COMMAND_R, FcitxKey_Super_R},
    {OSX_VK_OPTION_L, FcitxKey_Alt_L},
    {OSX_VK_OPTION_R, FcitxKey_Alt_R},

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

    // TODO: add others

    {0, FcitxKey_None}};

fcitx::KeySym osx_keycode_to_fcitx_keysym(uint16_t osxKeycode,
                                          uint32_t osxKeychar) {
    for (int i = 0; mappings[i].osxKeycode != 0; ++i) {
        if (mappings[i].osxKeycode == osxKeycode) {
            return mappings[i].keysym;
        }
    }
    if (isprint(osxKeychar)) {
        return fcitx::Key::keySymFromUnicode(osxKeychar);
    }
    return FcitxKey_None;
}

fcitx::KeyStates osx_modifiers_to_fcitx_keystates(unsigned int osxModifiers) {
    fcitx::KeyStates ret{};
    if (osxModifiers & OSX_MODIFIER_CAPSLOCK) {
        ret |= fcitx::KeyState::CapsLock;
    }
    if (osxModifiers & OSX_MODIFIER_SHIFT) {
        ret |= fcitx::KeyState::Shift;
    }
    if (osxModifiers & OSX_MODIFIER_CONTROL) {
        ret |= fcitx::KeyState::Ctrl;
    }
    if (osxModifiers & OSX_MODIFIER_OPTION) {
        ret |= fcitx::KeyState::Alt;
    }
    if (osxModifiers & OSX_MODIFIER_COMMAND) {
        ret |= fcitx::KeyState::Super;
    }
    return ret;
}
