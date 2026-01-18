#include "fcitx-utils/keysym.h"
#include "fcitx-utils/log.h"
#include "keycode.h"

void test_osx_to_fcitx() {
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, 0) == FcitxKey_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, kVK_ANSI_Keypad0) ==
                 FcitxKey_KP_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('a', 0, 0) == FcitxKey_a);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('a', NSEventModifierFlagShift,
                                             0) == FcitxKey_A);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(161 /* ¡ */,
                                             NSEventModifierFlagOption,
                                             kVK_ANSI_1) == FcitxKey_1);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(8260 /* ⁄ */,
                                             NSEventModifierFlagShift |
                                                 NSEventModifierFlagOption,
                                             kVK_ANSI_1) == FcitxKey_exclam);

    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_ANSI_0) == 11 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_ANSI_Keypad0) == 82 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_Shift) == 42 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_RightShift) == 54 + 8);

    FCITX_ASSERT(
        osx_modifiers_to_fcitx_keystates(NSEventModifierFlagControl |
                                         NSEventModifierFlagShift) ==
        (fcitx::KeyStates{} | fcitx::KeyState::Ctrl | fcitx::KeyState::Shift));
}

void test_fcitx_to_osx() {
    FCITX_ASSERT(fcitx_keysym_to_osx_function_key(FcitxKey_Up) == 0xF700);
    FCITX_ASSERT(fcitx_keysym_to_osx_function_key(FcitxKey_F12) == 0xF70F);

    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_Left) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_F12) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_0) == "0");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_KP_0) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_grave) == "`");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_a) == "a");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_A) == "a");

    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_KP_0) ==
                 kVK_ANSI_Keypad0);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_L) == kVK_Shift);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_R) ==
                 kVK_RightShift);

    FCITX_ASSERT(fcitx_keystates_to_osx_modifiers(fcitx::KeyStates{} |
                                                  fcitx::KeyState::Super |
                                                  fcitx::KeyState::Alt) ==
                 (NSEventModifierFlagCommand | NSEventModifierFlagOption));
}

void test_fcitx_string() {
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Left") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("F12") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+0") == "0");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+Shift+KP_0") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+slash") == "/");

    FCITX_ASSERT(fcitx_string_to_osx_modifiers("Control+Super+K") ==
                 (NSEventModifierFlagControl | NSEventModifierFlagCommand));

    FCITX_ASSERT(fcitx_string_to_osx_keycode("Alt+Shift+Shift_L") == kVK_Shift);
    FCITX_ASSERT(fcitx_string_to_osx_keycode("Shift_R") == kVK_RightShift);
}

int main() {
    test_osx_to_fcitx();
    test_fcitx_to_osx();
    test_fcitx_string();
}
