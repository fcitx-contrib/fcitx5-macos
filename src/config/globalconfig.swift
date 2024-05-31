import Fcitx
import Logging
import SwiftUI

class GlobalConfigController: ConfigWindowController {
  var view = ListConfigView("config/global", key: "global")

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Global Config", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.titlebarAppearsTransparent = true
    attachToolbar(window)
  }

  func refresh() {
    view.refresh()
  }
}
