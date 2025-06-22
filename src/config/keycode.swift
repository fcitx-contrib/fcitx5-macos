import Cocoa
import Keycode

func keyToUnicode(_ key: String) -> UInt32 {
  if key.isEmpty {
    return 0
  }
  let usv = key.unicodeScalars
  return usv[usv.startIndex].value
}

func macKeyToFcitxString(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ code: UInt16)
  -> String
{
  let unicode = keyToUnicode(key)
  return String(osx_key_to_fcitx_string(unicode, UInt32(modifiers.rawValue), code))
}

func fcitxStringToMacShortcut(_ s: String) -> (String, String?) {
  let key = String(fcitx_string_to_osx_keysym(s))
  let modifiers = NSEvent.ModifierFlags(rawValue: UInt(fcitx_string_to_osx_modifiers(s)))
  let code = fcitx_string_to_osx_keycode(s)
  if key.isEmpty && code == 0 {
    return (s, nil)
  }
  return shortcutRepr(key, modifiers, code)
}
