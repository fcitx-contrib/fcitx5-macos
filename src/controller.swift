import CxxStdlib
import Fcitx
import InputMethodKit
import SwiftFcitx

class FcitxInputController: IMKInputController {
  var cookie: UInt64
  var appId: String
  var lastModifiers = NSEvent.ModifierFlags(rawValue: 0)

  // A new InputController is created for each server-client
  // connection. We use the finest granularity here (one InputContext
  // for one IMKTextInput), and pass the bundle identifier to let
  // libfcitx handle the heavylifting.
  override init(server: IMKServer!, delegate: Any!, client: Any!) {
    if let client = client as? IMKTextInput {
      appId = client.bundleIdentifier() ?? ""
    } else {
      appId = ""
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

    let code = event.keyCode
    let mods = event.modifierFlags
    let modsVal = UInt32(mods.rawValue)

    switch event.type {
    case .keyDown:
      var unicode: UInt32 = 0
      if let characters = event.characters {
        let usv = characters.unicodeScalars
        unicode = usv[usv.startIndex].value
        // Send x[state:ctrl] instead of ^X[state:ctrl] to fcitx.
        unicode = removeCtrl(char: unicode)
      }
      let handled = process_key(cookie, unicode, modsVal, code, false)
      return handled
    case .flagsChanged:
      let change = NSEvent.ModifierFlags(rawValue: mods.rawValue ^ lastModifiers.rawValue)
      let isRelease: Bool = (lastModifiers.rawValue & change.rawValue) != 0
      var handled = false
      if change.contains(.shift) || change.contains(.control) || change.contains(.command)
        || change.contains(.option) || change.contains(.capsLock)
      {
        handled = process_key(cookie, 0, modsVal, code, isRelease)
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

  override func activateServer(_ client: Any!) {
    focus_in(cookie)
  }

  override func deactivateServer(_ client: Any!) {
    focus_out(cookie)
  }

  override func menu() -> NSMenu! {
    let menu = NSMenu()

    // Group switcher
    let groupNames = String(input_method_groups()).split(separator: "\n")
    let currentGroup = String(get_current_input_method_group())
    if groupNames.count > 1 {
      for groupName in groupNames {
        let groupName = String(groupName)
        let item = NSMenuItem(title: groupName, action: #selector(switchGroup), keyEquivalent: "")
        item.representedObject = groupName
        if groupName == currentGroup {
          item.state = .on
        }
        menu.addItem(item)
      }
      menu.addItem(NSMenuItem.separator())
    }

    // Input method switcher
    let inputMethodPairs = String(input_method_list()).split(separator: "\n")
    let currentIM = String(get_current_input_method())
    for inputMethodPair in inputMethodPairs {
      let parts = inputMethodPair.split(separator: ":", maxSplits: 1)
      let imName = String(parts[0])
      let nativeName = String(parts[1])
      let item = NSMenuItem(
        title: nativeName,
        action: #selector(switchInputMethod),
        keyEquivalent: ""
      )
      item.representedObject = imName
      if imName == currentIM {
        item.state = .on
      }
      menu.addItem(item)
    }
    menu.addItem(NSMenuItem.separator())

    menu.addItem(withTitle: "Restart", action: #selector(restart(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "About Fcitx5 macOS", action: #selector(about(_:)), keyEquivalent: "")
    return menu
  }

  @objc func switchGroup(sender: Any?) {
    if let groupName = repObjectIMK(sender) as? String {
      set_current_input_method_group(groupName)
    }
  }

  @objc func switchInputMethod(sender: Any?) {
    if let imName = repObjectIMK(sender) as? String {
      set_current_input_method(imName)
    }
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

/// Extract the representedObject of the sender of an IMK menu action.
///
/// The sender of an IMK menu action is a NSMutableDictionary:
/// {
///     IMKCommandClient = "<IPMDServerClientWrapper: 0x6000002a41e0>";
///     IMKCommandMenuItem = "<NSMenuItem: 0x6000018818f0 Other>";
///     IMKMenuTitle = Other;
/// }
private func repObjectIMK(_ sender: Any?) -> Any? {
  if let sender = sender as? NSMutableDictionary {
    if let menuItem = sender["IMKCommandMenuItem"] as? NSMenuItem {
      return menuItem.representedObject
    }
  }
  return nil
}
