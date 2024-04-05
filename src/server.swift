import Cocoa
import Fcitx
import Foundation
import InputMethodKit
import Logging
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

    let locale = Locale.current
    let languageCode = locale.language.languageCode?.identifier ?? "C"
    let localeIdent =
      if let r = locale.region?.identifier {
        languageCode + "_" + r
      } else {
        languageCode
      }
    FCITX_DEBUG("System locale = \(locale.identifier), localeIdent = \(localeIdent)")
    start_fcitx_thread(localeIdent)
  }

  func applicationWillTerminate(_ notification: Notification) {
    stop_fcitx_thread()
  }
}
