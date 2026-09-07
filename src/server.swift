import Cocoa
import Fcitx
import FcitxConfigUI
import InputMethodKit
import SwiftFrontend
import SwiftNotify

class NSManualApplication: NSApplication {
  private let appDelegate = AppDelegate()

  override init() {
    super.init()
    self.delegate = appDelegate
  }

  required init?(coder: NSCoder) {
    fatalError("Unreachable path")
  }
}

// Redirect stderr to /tmp/Fcitx5.log as it's not captured anyway.
private func redirectStderr() {
  let file = fopen("/tmp/Fcitx5.log", "w")
  if let file = file {
    dup2(fileno(file), STDERR_FILENO)
    fclose(file)
  }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  nonisolated(unsafe) static var server: IMKServer!
  nonisolated(unsafe) static var notificationDelegate: NotificationDelegate!
  nonisolated(unsafe) static var statusItem: NSStatusItem?
  nonisolated(unsafe) static var statusItemText: String = "🐧"
  nonisolated(unsafe) static var statusItemMode: Int32 = 0
  nonisolated(unsafe) static var cachedStatusItemPosition: Any?

  private static let statusItemAutosaveName: NSStatusItem.AutosaveName = "fcitx5"
  private static let statusItemPositionKey =
    "NSStatusItem Preferred Position \(statusItemAutosaveName)"
  private static let inputSourceChangedNotification = Notification.Name(
    rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String)
  private var positionObserver: NSObjectProtocol?

  private var sigtermSource: DispatchSourceSignal!

  private func installSignalHandlers() {
    signal(SIGTERM, SIG_IGN)
    sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler {
      Task { @MainActor in
        restartProcess()
      }
    }
    sigtermSource.resume()
  }

  /// Installs the standard Edit menu so Command-key editing shortcuts are handled by the
  /// application's responder chain before they reach the input method.
  ///
  /// In a regular macOS app, menu key equivalents such as Cmd+A, Cmd+C, and Cmd+V are consumed by
  /// the Edit menu before the field editor asks the current input method to handle a key event.
  /// Fcitx5 wires its AppKit lifecycle without a SwiftUI App scene or MainMenu nib, so it does not
  /// get that menu automatically.
  /// Without this function, those Command-key events fall through to the SwiftUI field editor and
  /// then enter Fcitx5 itself as input-method events, but they have no text-key-binding fallback.
  ///
  /// Ctrl+A and Ctrl+E work without this menu because they are `NSTextView` key bindings rather than
  /// menu key equivalents. They reach Fcitx5 first, and after Fcitx5 returns them as unhandled,
  /// `NSTextView` interprets them as commands to move to the beginning or end of the text.
  @MainActor
  private func installMainMenu() {
    let mainMenu = NSMenu()

    // The first item in a macOS main menu is reserved for the application menu.
    // Fcitx5 does not need any application-level commands here, but keeping the
    // placeholder ensures that Edit is presented as a normal top-level menu.
    let applicationName =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Fcitx5"
    let applicationItem = NSMenuItem(title: applicationName, action: nil, keyEquivalent: "")
    applicationItem.submenu = NSMenu(title: applicationName)
    mainMenu.addItem(applicationItem)

    let editTitle = NSLocalizedString("Edit", comment: "menu title")
    let editMenu = NSMenu(title: editTitle)
    let editItem = NSMenuItem(title: editTitle, action: nil, keyEquivalent: "")
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    func addEditingItem(
      _ title: String, _ action: Selector, _ keyEquivalent: String,
      modifiers: NSEvent.ModifierFlags = .command
    ) {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
      item.keyEquivalentModifierMask = modifiers
      editMenu.addItem(item)
    }

    // macOS automatically apply translation for undo and redo, maybe for the dynamic display of 撤销 and 撤销键入.
    addEditingItem("Undo", Selector(("undo:")), "z")
    addEditingItem(
      "Redo", Selector(("redo:")), "z", modifiers: [.command, .shift])
    editMenu.addItem(.separator())
    addEditingItem(
      NSLocalizedString("Cut", comment: "Edit menu item"), #selector(NSText.cut(_:)), "x")
    addEditingItem(
      NSLocalizedString("Copy", comment: "Edit menu item"), #selector(NSText.copy(_:)), "c")
    addEditingItem(
      NSLocalizedString("Paste", comment: "Edit menu item"), #selector(NSText.paste(_:)), "v")
    editMenu.addItem(.separator())
    addEditingItem(
      NSLocalizedString("Select All", comment: "Edit menu item"), #selector(NSText.selectAll(_:)),
      "a")

    NSApp.mainMenu = mainMenu
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    redirectStderr()

    installMainMenu()

    // Once process started, WKWebView doesn't accept new font files. Record and prompt user restart if needed.
    initUserFontFamiliesOnStart()

    installSignalHandlers()

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(inputSourceChanged),
      name: AppDelegate.inputSourceChangedNotification,
      object: nil)

    // Preserve status item position when macOS clears it after isVisible = false.
    positionObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      let key = AppDelegate.statusItemPositionKey
      if UserDefaults.standard.object(forKey: key) == nil,
        let position = AppDelegate.cachedStatusItemPosition
      {
        UserDefaults.standard.set(position, forKey: key)
      }
    }

    setStatusItemCallback { mode, text in
      if let mode = mode {
        AppDelegate.statusItemMode = mode
      }
      if let text = text {
        AppDelegate.statusItemText = prefixForStatusItem(text)
      }
      self.refreshStatusItemVisibility()
    }

    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)

    // Initialize notifications.
    AppDelegate.notificationDelegate = NotificationDelegate()
    AppDelegate.notificationDelegate.requestAuthorization()

    let locale = getLocale()
    start_fcitx_thread(locale)
  }

  func applicationWillTerminate(_ notification: Notification) {
    DistributedNotificationCenter.default().removeObserver(self)
    if let observer = positionObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    stop_fcitx_thread()
  }

  private func isFcitxSelectedInputSource() -> Bool {
    guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
      let property = TISGetInputSourceProperty(inputSource, kTISPropertyBundleID)
    else {
      return false
    }
    let bundleId = Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    return bundleId == Bundle.main.bundleIdentifier
  }

  @MainActor
  private func hideStatusItem() {
    guard let statusItem = AppDelegate.statusItem, statusItem.isVisible else { return }
    AppDelegate.cachedStatusItemPosition = UserDefaults.standard.object(
      forKey: AppDelegate.statusItemPositionKey)
    statusItem.isVisible = false
  }

  @MainActor
  private func showStatusItem() {
    let statusItem: NSStatusItem
    if let existing = AppDelegate.statusItem {
      statusItem = existing
    } else {
      // NSStatusItem.variableLength causes layout shift of icons on the left when switching between en and 拼.
      let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      newItem.autosaveName = AppDelegate.statusItemAutosaveName
      AppDelegate.statusItem = newItem
      statusItem = newItem
    }

    if !statusItem.isVisible {
      if let position = AppDelegate.cachedStatusItemPosition {
        UserDefaults.standard.set(position, forKey: AppDelegate.statusItemPositionKey)
      }
      statusItem.isVisible = true
    }
    statusItem.menu = nil

    if let button = statusItem.button {
      button.title = AppDelegate.statusItemText
      button.target = self
      button.action = nil
      if AppDelegate.statusItemMode == 1 {
        button.action = #selector(self.toggle)
      } else {
        statusItem.menu = makeStatusItemMenu()
      }
    }
  }

  @MainActor
  private func makeStatusItemMenu() -> NSMenu {
    let menu = NSMenu()

    let toggle = NSMenuItem(
      title: NSLocalizedString("Toggle input method", comment: ""),
      action: #selector(self.toggle), keyEquivalent: "")
    toggle.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
    menu.addItem(toggle)

    menu.addItem(NSMenuItem.separator())

    let hide = NSMenuItem(
      title: NSLocalizedString("Hide", comment: ""),
      action: #selector(self.hide), keyEquivalent: "")
    hide.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
    menu.addItem(hide)

    return menu
  }

  @MainActor
  private func refreshStatusItemVisibility() {
    guard AppDelegate.statusItemMode != 0, isFcitxSelectedInputSource() else {
      hideStatusItem()
      return
    }
    showStatusItem()
  }

  @MainActor
  @objc private func inputSourceChanged(_ notification: Notification) {
    refreshStatusItemVisibility()
  }

  @objc func toggle() {
    toggleInputMethod()
  }

  @MainActor
  @objc func hide() {
    Fcitx.setConfig("fcitx://config/addon/macosfrontend", "{\"StatusBar\": \"Hidden\"}")
    ConfigWindowController.refreshAll()  // Refresh Advanced.
    sendNotification(
      "status-item-hidden", "", NSLocalizedString("Status bar is hidden", comment: ""),
      NSLocalizedString("You may re-enable it in Advanced → macOS Frontend.", comment: ""), [], 8000
    )
  }
}
