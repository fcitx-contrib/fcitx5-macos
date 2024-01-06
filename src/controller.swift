import CxxStdlib
import Fcitx
import InputMethodKit
import SwiftFcitx

class FcitxInputController: IMKInputController {
  var lastModifiers = NSEvent.ModifierFlags(rawValue: 0)

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
      var unicode: UInt32 = 0
      if let characters = event.characters {
        let usv = characters.unicodeScalars
        unicode = usv[usv.startIndex].value
        // Send x[state:ctrl] instead of ^\X[state:ctrl] to fcitx.
        unicode = removeCtrl(char: unicode)
      }
      let code = event.keyCode
      let modifiers = UInt32(event.modifierFlags.rawValue)
      let handled = process_key(unicode, modifiers, code, false)
      return handled
    case .flagsChanged:
      let code = event.keyCode
      let mods = event.modifierFlags
      let modsVal = UInt32(mods.rawValue)
      let change = NSEvent.ModifierFlags(rawValue: mods.rawValue ^ lastModifiers.rawValue)
      let isRelease: Bool = (lastModifiers.rawValue & change.rawValue) != 0
      var handled = false
      if change.contains(.shift) {
        handled = process_key(0, modsVal, code, isRelease)
      } else if change.contains(.control) {
        handled = process_key(0, modsVal, code, isRelease)
      } else if change.contains(.command) {
        handled = process_key(0, modsVal, code, isRelease)
      } else if change.contains(.option) {
        handled = process_key(0, modsVal, code, isRelease)
      } else if change.contains(.capsLock) {
        handled = process_key(0, modsVal, code, isRelease)
      }
      lastModifiers = mods
      return handled
    default:
      NSLog("Unhandled event: \(String(describing: event.type))")
      return false
    }
  }

  override func candidates(_ sender: Any!) -> [Any]! {
    return getCandidateList()
  }
}

/// Convert a character like ^X to the corresponding lowercase letter x.
private func removeCtrl(char: UInt32) -> UInt32 {
  if char >= 0x00 && char <= 0x1F {
    return char + 0x60
  } else {
    return char
  }
}
