#include <cassert>
#include "keycode.h"
#include "macosfrontend-public.h"

void test_osx_to_fcitx() {
    assert(osx_unicode_to_fcitx_keysym('0', 0, 0) == FcitxKey_0);
    assert(osx_unicode_to_fcitx_keysym('0', 0, OSX_VK_KEYPAD_0) ==
           FcitxKey_KP_0);
    assert(osx_unicode_to_fcitx_keysym('a', 0, 0) == FcitxKey_a);
    assert(osx_unicode_to_fcitx_keysym('a', OSX_MODIFIER_SHIFT, 0) ==
           FcitxKey_A);

    assert(osx_keycode_to_fcitx_keycode(OSX_VK_KEY_0) == 11 + 8);
    assert(osx_keycode_to_fcitx_keycode(OSX_VK_KEYPAD_0) == 82 + 8);
    assert(osx_keycode_to_fcitx_keycode(OSX_VK_SHIFT_L) == 42 + 8);
    assert(osx_keycode_to_fcitx_keycode(OSX_VK_SHIFT_R) == 54 + 8);

    assert(
        osx_modifiers_to_fcitx_keystates(OSX_MODIFIER_CONTROL |
                                         OSX_MODIFIER_SHIFT) ==
        (fcitx::KeyStates{} | fcitx::KeyState::Ctrl | fcitx::KeyState::Shift));
}

void test_fcitx_to_osx() {
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_Up) == "\u{1e}");
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_0) == "0");
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_KP_0) == "");
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_grave) == "`");
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_a) == "a");
    assert(fcitx_keysym_to_osx_keysym(FcitxKey_A) == "a");

    assert(fcitx_keysym_to_osx_keycode(FcitxKey_KP_0) == OSX_VK_KEYPAD_0);
    assert(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_L) == OSX_VK_SHIFT_L);
    assert(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_R) == OSX_VK_SHIFT_R);

    assert(fcitx_keystates_to_osx_modifiers(fcitx::KeyStates{} |
                                            fcitx::KeyState::Super |
                                            fcitx::KeyState::Alt) ==
           (OSX_MODIFIER_COMMAND | OSX_MODIFIER_OPTION));
}

void test_fcitx_string() {
    assert(fcitx_string_to_osx_keysym("Left") == "\u{1c}");
    assert(fcitx_string_to_osx_keysym("Control+0") == "0");
    assert(fcitx_string_to_osx_keysym("Control+Shift+KP_0") == "");
    assert(fcitx_string_to_osx_keysym("Control+slash") == "/");

    assert(fcitx_string_to_osx_modifiers("Control+Super+K") ==
           (OSX_MODIFIER_CONTROL | OSX_MODIFIER_COMMAND));

    assert(fcitx_string_to_osx_keycode("Alt+Shift+Shift_L") == OSX_VK_SHIFT_L);
    assert(fcitx_string_to_osx_keycode("Shift_R") == OSX_VK_SHIFT_R);
}

int main() {
    test_osx_to_fcitx();
    test_fcitx_to_osx();
    test_fcitx_string();
}
