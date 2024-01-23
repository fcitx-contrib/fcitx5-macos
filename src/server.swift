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

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  static var server = IMKServer()
  static var notificationDelegate = NotificationDelegate()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)

    // Initialize notifications.
    AppDelegate.notificationDelegate.requestAuthorization()

    start_fcitx_thread()
  }

  func applicationWillTerminate(_ notification: Notification) {
    stop_fcitx_thread()
  }
}
