import CxxFrontend
import Fcitx
import InputMethodKit
import Logging
import SwiftFrontend
import SwiftyJSON

struct SyncResponse: Codable {
  let commit: String
  let preedit: String
  let caretPos: Int
  let dummyPreedit: Bool
  let accepted: Bool
}

let capsLock = 65536
let shift = 131072

class FcitxInputController: IMKInputController {
  var uuid: ICUUID
  var appId: String
  var lastModifiers = NSEvent.ModifierFlags(rawValue: 0)
  var ignoreRelease: Bool = false
  let client: Any!
  var accentColor = ""
  var selection: NSRange? = nil
  var lastEventIsShiftPress = false
  var obeySecureInput = true

  // A registry of live FcitxInputController objects.
  // Use NSHashTable to store weak references.
  static var registry = NSHashTable<FcitxInputController>.weakObjects()

  // A new InputController is created for each server-client
  // connection. We use the finest granularity here (one InputContext
  // for one IMKTextInput), and pass the bundle identifier to let
  // libfcitx handle the heavylifting.
  override init(server: IMKServer!, delegate: Any!, client: Any!) {
    if let client = client as? IMKTextInput {
      appId = client.bundleIdentifier() ?? ""
      accentColor = getAccentColor(appId)
    } else {
      appId = ""
    }
    self.client = client
    self.uuid = create_input_context(appId, client, accentColor)
    super.init(server: server, delegate: delegate, client: client)
    FcitxInputController.registry.add(self)
    // Do not clear in deinit, otherwise it will crash with
    // "Simultaneous accesses to 0x100e05650, but modification requires exclusive access."
    setController(self)
  }

  deinit {
    destroy_input_context(uuid)
    FcitxInputController.registry.remove(self)
  }

  func reconnectToFcitx() {
    // The old fcitx input context was automatically destroyed when
    // restarting fcitx thread. So just start a new one here.
    FCITX_DEBUG("Reconnecting to \(appId), client = \(String(describing: client))")
    uuid = create_input_context(appId, client, accentColor)
  }

  override func commitComposition(_ sender: Any!) {
    guard let client = client as? IMKTextInput else {
      return
    }
    let res = String(commit_composition(uuid))
    // Maybe commit and clear preedit synchronously if user switches to ABC by Ctrl+Space.
    // For Rime with CapsLock, the result will depend on ascii_composer/switch_key/Caps_Lock instead of fcitx5-rime config.
    let _ = processRes(client, res)
  }

  func processRes(_ client: IMKTextInput, _ res: String) -> Bool {
    guard let data = res.data(using: .utf8),
      let response = try? JSONDecoder().decode(SyncResponse.self, from: data)
    else {
      return false
    }
    commitAndSetPreeditSync(
      client, response.commit, response.preedit, response.caretPos, response.dummyPreedit)
    return response.accepted
  }

  // Normal apps like Chrome calls EnableSecureEventInput when its password input is focused,
  // and calls DisableSecureEventInput on blur of input or app itself. Abnormal apps call
  // EnableSecureEventInput but doesn't call DisableSecureEventInput on blur, so we can't
  // rely on IsSecureEventInputEnabled's true return value, as obeying it will lock keyboard-us.
  // Users observe https://discussions.apple.com/thread/253793652 but it's also possible that
  // other apps are abusing, see comments for getSecureInputProcessPID.
  func getSecureInputInfo(isOnFocus: Bool) -> Bool {
    if appId == "com.apple.loginwindow" {
      return true
    }
    if !IsSecureEventInputEnabled() {
      return false
    }
    if isOnFocus {
      let pid = getSecureInputProcessPID()
      let runningApp = pid == nil ? nil : NSRunningApplication(processIdentifier: pid!)
      obeySecureInput = runningApp?.bundleIdentifier == appId
      if !obeySecureInput {
        FCITX_WARN(
          "Secure input is abused by (possibly) \(runningApp?.localizedName ?? "?"): \(runningApp?.bundleIdentifier ?? "?") pid=\(pid ?? -1)"
        )
      }
    }
    // On keyDown, don't call getSecureInputProcessPID for performance.
    return obeySecureInput
  }

  func processKey(_ unicode: UInt32, _ modsVal: UInt32, _ code: UInt16, _ isRelease: Bool) -> Bool {
    guard let client = client as? IMKTextInput else {
      return false
    }
    let newSelection = client.selectedRange()
    let selectionChanged: Bool = selection != newSelection
    selection = newSelection
    var isShiftPress = false
    if code == 56 || code == 60 {
      if modsVal == shift || modsVal == (shift | capsLock) {
        isShiftPress = true
      } else if (modsVal == 0 || modsVal == capsLock) && lastEventIsShiftPress && selectionChanged {
        // Shift release following press when text selection is changed.
        // Send a no-op key event to fcitx so that Shift+Click doesn't trigger im toggle.
        process_key(uuid, 0, 0, 0, false, false)
      }
    }
    lastEventIsShiftPress = isShiftPress
    // It can change within an IMKInputController (e.g. sudo in Terminal), so must reevaluate before each key sent to IM.
    let isPassword = getSecureInputInfo(isOnFocus: false)
    let res = String(process_key(uuid, unicode, modsVal, code, isRelease, isPassword))
    return processRes(client, res)
  }

  // Default behavior is to recognize keyDown only
  override func recognizedEvents(_ sender: Any!) -> Int {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event, sender as? IMKTextInput != nil else {
      return false
    }

    let code = event.keyCode
    let mods = event.modifierFlags
    let modsVal = UInt32(mods.rawValue)

    switch event.type {
    case .keyDown:
      ignoreRelease = false
      var unicode: UInt32 = 0
      // For Shift+comma, charactersIgnoringModifiers is comma, characters is less.
      // For Control+Shift+comma, both are comma.
      // This behavior is different with what key recorder gets.
      // We need less for Shift+comma, so we use characters.
      // But then for Control+Shift+A, characters is \u{01}, so we remove the control key.
      if let characters = event.characters {
        unicode = removeCtrl(char: keyToUnicode(characters))
      }
      let handled = processKey(unicode, modsVal, code, false)
      return handled
    case .flagsChanged:
      let change = NSEvent.ModifierFlags(rawValue: mods.rawValue ^ lastModifiers.rawValue)
      let isRelease: Bool = (lastModifiers.rawValue & change.rawValue) != 0
      // HACK: binding a shortcut to a menu item will let system intercept the key event, and send leftover key release to fcitx.
      // e.g. On Pinyin status, Ctrl+Shift+F changes to traditional Chinese, but the release of Ctrl+Shift is sent to fcitx, which triggers English.
      // We ignore the release of leftover modifiers to prevent this, and reset the flag when all modifiers are released or any key is pressed.
      if !isRelease {
        ignoreRelease = false
      }
      var handled = false
      if isRelease && ignoreRelease {
        handled = true
        if mods.rawValue == 0 {
          ignoreRelease = false
        }
      } else if !change.isDisjoint(with: [.shift, .control, .command, .option, .capsLock]) {
        handled = processKey(0, modsVal, code, isRelease)
      }
      lastModifiers = mods
      return handled
    default:
      FCITX_ERROR("Unhandled event: \(String(describing: event.type))")
      return false
    }
  }

  // activateServer is called when app is in foreground but not necessarily a text field is selected.
  override func activateServer(_ client: Any!) {
    // overrideKeyboard is needed for pressing space to play in Shotcut.
    if let client = client as? IMKTextInput {
      client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
    }
    // Make sure status bar is updated on click password input, before first key event.
    let isPassword = getSecureInputInfo(isOnFocus: true)
    focus_in(uuid, isPassword)
  }

  override func deactivateServer(_ client: Any!) {
    focus_out(uuid)
  }

  override func menu() -> NSMenu! {
    let menu = NSMenu()

    // Group switcher
    let groupNames = JSON(parseJSON: String(Fcitx.imGetGroupNames())).arrayValue
    let currentGroup = String(Fcitx.imGetCurrentGroupName())
    if groupNames.count > 1 {
      for groupName in groupNames {
        let groupName = groupName.stringValue
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
    let curGroup = JSON(parseJSON: String(Fcitx.imGetCurrentGroup()))
    let currentIM = String(Fcitx.imGetCurrentIMName())
    for (_, inputMethod) in curGroup {
      let imName = inputMethod["name"].stringValue
      let nativeName = inputMethod["displayName"].stringValue
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

    // Additional actions for the current IC
    let actionJson = String(Fcitx.getActions())
    if let data = actionJson.data(using: .utf8) {
      do {
        let actions = try JSONDecoder().decode(Array<FcitxAction>.self, from: data)
        for action in actions {
          for item in action.toMenuItems(target: self) {
            menu.addItem(item)
          }
        }
        menu.addItem(NSMenuItem.separator())
      } catch {
        FCITX_ERROR("Error decoding actions: \(error)")
      }
    }

    menu.addItem(
      withTitle: NSLocalizedString("Input Methods", comment: ""),
      action: #selector(inputMethod(_:)), keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("Global Config", comment: ""),
      action: #selector(globalConfig(_:)), keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("Theme Editor", comment: ""), action: #selector(themeEditor(_:)),
      keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("Plugin Manager", comment: ""), action: #selector(plugin(_:)),
      keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("Advanced", comment: ""), action: #selector(advanced(_:)),
      keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("Restart", comment: ""), action: #selector(restart(_:)),
      keyEquivalent: "")
    menu.addItem(
      withTitle: NSLocalizedString("About Fcitx5 macOS", comment: ""), action: #selector(about(_:)),
      keyEquivalent: "")
    return menu
  }

  @objc func switchGroup(sender: Any?) {
    if let groupName = repObjectIMK(sender) as? String {
      Fcitx.imSetCurrentGroup(groupName)
    }
  }

  @objc func switchInputMethod(sender: Any?) {
    if let imName = repObjectIMK(sender) as? String {
      Fcitx.imSetCurrentIM(imName)
    }
  }

  @objc func activateFcitxAction(sender: Any?) {
    ignoreRelease = true
    if let action = repObjectIMK(sender) as? FcitxAction {
      Fcitx.activateActionById(Int32(action.id))
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
    if let menuItem = sender[kIMKCommandMenuItemName] as? NSMenuItem {
      return menuItem.representedObject
    }
  }
  return nil
}

struct FcitxKey: Codable {
  let sym: String
  let functionKey: UInt16
  let states: UInt
}

struct FcitxAction: Codable {
  let id: Int
  let name: String
  let desc: String
  let checked: Bool?
  let children: [FcitxAction]?
  let separator: Bool?
  let hotkey: [FcitxKey]?

  // Returns a flattened array of the menu item and all of its children.
  // Cannot use submenus directly because IMK submenus do not work as expected.
  func toMenuItems(target: AnyObject, _ depth: Int = 0) -> [NSMenuItem] {
    if separator ?? false {
      // Separators should be skipped in a flattened view.
      return []
    }

    var keyEquivalent = ""
    if let key = hotkey?[0] {
      if !key.sym.isEmpty {
        keyEquivalent = key.sym
      } else if key.functionKey != 0 {
        keyEquivalent = String(
          utf16CodeUnits: [unichar(key.functionKey)], count: 1)
      }
    }
    let item = NSMenuItem(
      title: String(repeating: "　　", count: depth) + desc,
      action: #selector(FcitxInputController.activateFcitxAction),
      keyEquivalent: keyEquivalent)
    item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: hotkey?[0].states ?? 0)
    item.target = target
    item.representedObject = self
    if let checked = checked {
      item.state = checked ? .on : .off
    }

    var items = [item]

    for child in children ?? [] {
      items += child.toMenuItems(target: target, depth + 1)
    }

    return items
  }
}

func toggleInputMethod() {
  Fcitx.toggleInputMethod()
}
