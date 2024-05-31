import Fcitx
import Logging
import SwiftUI

class ThemeEditorController: ConfigWindowController {
  var view = ListConfigView("config/addon/webpanel", key: "theme")

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Theme Editor", comment: "")
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
