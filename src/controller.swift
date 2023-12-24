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
    var keySym = ""
    switch event.type {
    case .keyDown:
      if let characters = event.characters {
        keySym = characters
      }
    default:
      NSLog("\(event.type)")
    }
    let accepted = process_key(std.string(keySym))
    return accepted
  }

  override func candidates(_ sender: Any!) -> [Any]! {
    return getCandidateList()
  }
}
