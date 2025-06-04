import Cocoa
import Fcitx
import InputMethodKit
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

  func applicationDidFinishLaunching(_ notification: Notification) {
    redirectStderr()

    signal(SIGTERM, signalHandler)

    // NSStatusItem.variableLength causes layout shift of icons on the left when switching between en and 拼.
    AppDelegate.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = AppDelegate.statusItem?.button {
      button.action = #selector(handleStatusItemClick)
      button.target = self
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

  @objc func handleStatusItemClick() {
    toggleInputMethod()
  }
}
