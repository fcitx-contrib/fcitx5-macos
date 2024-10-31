import SwiftUI

let notificationPrefix = "Fcitx5Config"

let aboutNotification = "\(notificationPrefix)About"
let pluginNotification = "\(notificationPrefix)Plugin"

class AppDelegate: NSObject, NSApplicationDelegate {
  static var pluginManager: PluginManager = {
    return PluginManager()
  }()

  static var fcitxAbout: FcitxAboutController = {
    return FcitxAboutController()
  }()

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let center = DistributedNotificationCenter.default()
    center.addObserver(
      forName: .init(aboutNotification), object: nil, queue: nil
    ) { _ in
      self.showAbout()
    }
    center.addObserver(
      forName: .init(pluginNotification), object: nil, queue: nil
    ) { _ in
      self.showPluginManager()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    DistributedNotificationCenter.default().removeObserver(self)
  }

  func showWindow(_ targetWindow: String) {
    switch targetWindow {
    case "About":
      showAbout()
    case "Plugin":
      showPluginManager()
    default:
      break
    }
  }

  func showAbout() {
    AppDelegate.fcitxAbout.refresh()
    AppDelegate.fcitxAbout.showWindow(nil)
  }

  func showPluginManager() {
    AppDelegate.pluginManager.refreshPlugins()
    AppDelegate.pluginManager.showWindow(nil)
  }
}
