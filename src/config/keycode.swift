import Cocoa
import CxxFrontend

private func keyToUnicode(_ key: String) -> UInt32 {
  if key.isEmpty {
    return 0
  }
  let usv = key.unicodeScalars
  return usv[usv.startIndex].value
}

func macKeyToFcitxString(_ key: String, _ modifier: NSEvent.ModifierFlags, _ code: UInt16) -> String
{
  let unicode = keyToUnicode(key)
  return String(osx_key_to_fcitx_string(unicode, UInt32(modifier.rawValue), code))
}
