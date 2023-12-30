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
      var unicode: UInt32 = 0
      if let characters = event.characters {
        let usv = characters.unicodeScalars
        unicode = usv[usv.startIndex].value
      }
      let code = event.keyCode
      let modifiers = UInt32(event.modifierFlags.rawValue)
      let handled = process_key(unicode, modifiers, code)
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
