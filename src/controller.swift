import CxxStdlib
import Fcitx
import InputMethodKit
import SwiftFcitx

class FcitxInputController: IMKInputController {
  var cookie: UInt64
  var appId: String

  // A new InputController is created for each server-client
  // connection. We use the finest granularity here (one InputContext
  // for one IMKTextInput), and pass the bundle identifier to let
  // libfcitx handle the heavylifting.
  override init(server: IMKServer!, delegate: Any!, client: Any!) {
    if let client = client as? IMKTextInput {
      appId = client.bundleIdentifier() ?? "unknown"
    } else {
      appId = "unknown"
    }
    cookie = create_input_context(appId)
    super.init(server: server, delegate: delegate, client: client)
  }

  deinit {
    destroy_input_context(cookie)
  }

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
      let handled = process_key(cookie, unicode, modifiers, code)
      return handled
    default:
      NSLog("Unhandled event: \(String(describing: event.type))")
      return false
    }
  }

  override func candidates(_ sender: Any!) -> [Any]! {
    return getCandidateList()
  }

  override func activateServer(_ client: Any!) {
    focus_in(cookie)
  }

  override func deactivateServer(_ client: Any!) {
    focus_out(cookie)
  }
}
