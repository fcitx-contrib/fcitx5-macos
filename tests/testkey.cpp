#include "fcitx-utils/log.h"
#include "keycode.h"

void test_osx_to_fcitx() {
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, 0) == FcitxKey_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, OSX_VK_KEYPAD_0) ==
                 FcitxKey_KP_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('a', 0, 0) == FcitxKey_a);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('a', OSX_MODIFIER_SHIFT, 0) ==
                 FcitxKey_A);

    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(OSX_VK_KEY_0) == 11 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(OSX_VK_KEYPAD_0) == 82 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(OSX_VK_SHIFT_L) == 42 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(OSX_VK_SHIFT_R) == 54 + 8);

    FCITX_ASSERT(
        osx_modifiers_to_fcitx_keystates(OSX_MODIFIER_CONTROL |
                                         OSX_MODIFIER_SHIFT) ==
        (fcitx::KeyStates{} | fcitx::KeyState::Ctrl | fcitx::KeyState::Shift));
}

void test_fcitx_to_osx() {
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_Up) == "\u{1e}");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_0) == "0");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_KP_0) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_grave) == "`");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_a) == "a");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_A) == "a");

    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_KP_0) == OSX_VK_KEYPAD_0);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_L) ==
                 OSX_VK_SHIFT_L);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_R) ==
                 OSX_VK_SHIFT_R);

    FCITX_ASSERT(fcitx_keystates_to_osx_modifiers(fcitx::KeyStates{} |
                                                  fcitx::KeyState::Super |
                                                  fcitx::KeyState::Alt) ==
                 (OSX_MODIFIER_COMMAND | OSX_MODIFIER_OPTION));
}

void test_fcitx_string() {
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Left") == "\u{1c}");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+0") == "0");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+Shift+KP_0") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+slash") == "/");

    FCITX_ASSERT(fcitx_string_to_osx_modifiers("Control+Super+K") ==
                 (OSX_MODIFIER_CONTROL | OSX_MODIFIER_COMMAND));

    FCITX_ASSERT(fcitx_string_to_osx_keycode("Alt+Shift+Shift_L") ==
                 OSX_VK_SHIFT_L);
    FCITX_ASSERT(fcitx_string_to_osx_keycode("Shift_R") == OSX_VK_SHIFT_R);
}

int main() {
    test_osx_to_fcitx();
    test_fcitx_to_osx();
    test_fcitx_string();
}
