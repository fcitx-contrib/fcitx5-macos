import Cocoa
import Fcitx
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

private func signalHandler(signal: Int32) {
  // The signal can be raised on any thread. So we must make sure it's
  // routed back to the main thread.
  DispatchQueue.main.async {
    if signal == SIGTERM {
      NSApplication.shared.terminate(nil)
    }
  }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  static var server = IMKServer()
  static var notificationDelegate = NotificationDelegate()
  static var statusItem: NSStatusItem?
  static var statusItemText: String = "🐧"

  func applicationDidFinishLaunching(_ notification: Notification) {
    redirectStderr()

    signal(SIGTERM, signalHandler)

    setStatusItemCallback { mode, text in
      // Main thread could call fcitx thread which then calls this, so must be async.
      DispatchQueue.main.async { [self] in
        if let mode = mode {
          if mode == 0 {  // Hidden
            AppDelegate.statusItem = nil
          } else {
            // NSStatusItem.variableLength causes layout shift of icons on the left when switching between en and 拼.
            let statusItem: NSStatusItem = NSStatusBar.system.statusItem(
              withLength: NSStatusItem.variableLength)
            AppDelegate.statusItem = statusItem
            if let button = statusItem.button {
              button.title = AppDelegate.statusItemText
              button.target = self
              if mode == 1 {  // Toggle input method
                button.action = #selector(toggle)
              } else  // Menu
              {
                let menu = NSMenu()
                menu.addItem(
                  NSMenuItem(
                    title: NSLocalizedString("Toggle input method", comment: ""),
                    action: #selector(toggle), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(
                  NSMenuItem(
                    title: NSLocalizedString("Hide", comment: ""),
                    action: #selector(hide), keyEquivalent: ""))
                statusItem.menu = menu
              }
            }
          }
        }
        if let text = text {
          AppDelegate.statusItemText = text
          if let button = AppDelegate.statusItem?.button {
            button.title = text
          }
        }
      }
    }

    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)

    // Initialize notifications.
    AppDelegate.notificationDelegate.requestAuthorization()

    let locale = getLocale()
    start_fcitx_thread(locale)
  }

  func applicationWillTerminate(_ notification: Notification) {
    stop_fcitx_thread()
  }

  @objc func toggle() {
    toggleInputMethod()
  }

  @objc func hide() {
    Fcitx.setConfig("fcitx://config/addon/macosfrontend", "{\"StatusBar\": \"Hidden\"}")
  }
}
