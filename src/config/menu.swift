import Cocoa
import Fcitx

@MainActor
func restartAndReconnect(_ actionBetween: (() -> Void)? = nil) {
  stop_fcitx_thread()
  actionBetween?()
  start_fcitx_thread(nil)
  for controller in FcitxInputController.registry.allObjects {
    controller.reconnectToFcitx()
  }
}

// Don't call it synchronously in SwiftUI as it will make IM temporarily unavailable in focused client.
func restartProcess() {
  NSApp.terminate(nil)
}

extension FcitxInputController {
  static var controllers = [String: ConfigWindowController]()

  func openWindow(_ key: String, _ type: ConfigWindowController.Type) {
    var controller = FcitxInputController.controllers[key]
    if controller == nil {
      controller = type.init()
      controller?.setKey(key)
      FcitxInputController.controllers[key] = controller
    }
    controller?.refresh()
    controller?.showWindow(nil)
  }

  static func closeWindow(_ key: String) {
    FcitxInputController.controllers[key]?.window?.performClose(nil)
  }

  @objc func plugin(_: Any? = nil) {
    openWindow("plugin", PluginManager.self)
  }

  @objc func restart(_: Any? = nil) {
    restartProcess()
  }

  @objc func about(_: Any? = nil) {
    openWindow("about", FcitxAboutController.self)
  }

  @objc func globalConfig(_: Any? = nil) {
    openWindow("global", GlobalConfigController.self)
  }

  @objc func inputMethod(_: Any? = nil) {
    openWindow("im", InputMethodConfigController.self)
  }

  @objc func themeEditor(_: Any? = nil) {
    openWindow("theme", ThemeEditorController.self)
  }

  @objc func advanced(_: Any? = nil) {
    openWindow("advanced", AdvancedController.self)
  }
}

/// All config window controllers should subclass this.  It sets up
/// application states so that the config windows can receive user
/// input.
class ConfigWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
  var key: String = ""

  override init(window: NSWindow?) {
    super.init(window: window)
    if let window = window {
      window.delegate = self
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func showWindow(_ sender: Any? = nil) {
    if let window = window {
      // Switch to normal activation policy so that the config windows
      // can receive key events.
      if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
      }

      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    // Free memory and reset state.
    FcitxInputController.controllers.removeValue(forKey: key)
    // Switch back.
    if FcitxInputController.controllers.count == 0 {
      NSApp.setActivationPolicy(.prohibited)
    }
    return false
  }

  func attachToolbar(_ window: NSWindow) {
    // Prior to macOS 14.0, NSHostingView doesn't host toolbars, and
    // we have to create a toolbar manually.
    //
    // Cannot use #available check here because it's a runtime check,
    // but the following code should work nevertheless: NSHostingView
    // will replace the toolbar if it works.
    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.showsBaselineSeparator = false
    window.toolbar = toolbar
    window.toolbarStyle = .unified
  }

  func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    if itemIdentifier == .toggleSidebar {
      let item = NSToolbarItem(itemIdentifier: .toggleSidebar)
      item.label = NSLocalizedString("Toggle Sidebar", comment: "label")
      item.paletteLabel = NSLocalizedString("Toggle Sidebar", comment: "label")
      item.toolTip = NSLocalizedString("Toggle the visibility of the sidebar", comment: "tooltip")
      item.target = self
      item.action = #selector(toggleSidebar)
      return item
    }
    return nil
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.toggleSidebar, .flexibleSpace]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.toggleSidebar, .flexibleSpace]
  }

  @objc func toggleSidebar(_ sender: Any?) {
    // Wow, we don't have to do anything here.
  }

  func setKey(_ key: String) {
    self.key = key
  }

  func refresh() {}
}
