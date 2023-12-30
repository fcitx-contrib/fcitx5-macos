import CxxStdlib
import Fcitx
import InputMethodKit
import SwiftFcitx

class FcitxInputController: IMKInputController {
  // Default behavior is to recognize keyDown only
  override func recognizedEvents(_ sender: Any!) -> Int {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event, let client = sender as? IMKTextInput else {
      return false
    }
    setClient(client)
    switch event.type {
    case .keyDown:
      let code = event.keyCode
      let char = event.charactersIgnoringModifiers!.unicodeScalars.first ?? UnicodeScalar(0)
      let modifiers = event.modifierFlags
      let handled = process_key(code, char!.value, UInt64(modifiers.rawValue))
      NSLog("Keydown: keyCode=\(code) char=\(char!) modifiers=\(modifierFlagsToString(modifiers: modifiers)) handled?=\(handled)")
      return handled
    default:
      NSLog("Unhandled event: \(String(describing: event.type))")
      return false
    }
  }

  override func candidates(_ sender: Any!) -> [Any]! {
    return getCandidateList()
  }

  override func activateServer(_ sender: Any!) {}

  override func deactivateServer(_ sender: Any!) {}
}

func modifierFlagsToString(modifiers: NSEvent.ModifierFlags) -> String {
  var ret = ""
  if modifiers.contains(.capsLock) { ret += "c" }
  if modifiers.contains(.shift) { ret += "S" }
  if modifiers.contains(.control) { ret += "C" }
  if modifiers.contains(.option) { ret += "O" }
  if modifiers.contains(.command) { ret += "M" }
  if modifiers.contains(.numericPad) { ret += "n" }
  if modifiers.contains(.help) { ret += "h" }
  if modifiers.contains(.function) { ret += "f" }
  return ret
}
