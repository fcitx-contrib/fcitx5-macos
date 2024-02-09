import Cocoa
import Fcitx

extension FcitxInputController {
  static var fcitxAbout: NSWindowController = {
    return FcitxAbout()
  }()
  static var pluginManager: PluginManager = {
    return PluginManager()
  }()
  static var globalConfigController: GlobalConfigController = {
    return GlobalConfigController()
  }()
  static var inputMethodConfigController: InputMethodConfigController = {
    return InputMethodConfigController()
  }()

  @objc func plugin(_: Any? = nil) {
    FcitxInputController.pluginManager.refreshPlugins()
    FcitxInputController.pluginManager.showWindow(nil)
  }

  @objc func restart(_: Any? = nil) {
    restart_fcitx_thread()
    for controller in FcitxInputController.registry.allObjects {
      controller.reconnectToFcitx()
    }
  }

  @objc func about(_: Any? = nil) {
    FcitxInputController.fcitxAbout.showWindow(nil)
  }

  @objc func globalConfig(_: Any? = nil) {
    FcitxInputController.globalConfigController.showWindow(nil)
  }

  @objc func inputMethod(_: Any? = nil) {
    FcitxInputController.inputMethodConfigController.showWindow(nil)
  }
}

/// All config window controllers should subclass this.  It sets up
/// application states so that the config windows can receive user
/// input.
class ConfigWindowController: NSWindowController, NSWindowDelegate {
  static var numberOfConfigWindows: Int = 0

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
      if !window.isVisible {
        ConfigWindowController.numberOfConfigWindows += 1
      }

      window.makeKeyAndOrderFront(nil)

      // Switch to normal activation policy so that the config windows
      // can receive key events.
      if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
      }
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    ConfigWindowController.numberOfConfigWindows -= 1

    // Switch back.
    if ConfigWindowController.numberOfConfigWindows <= 0 {
      NSApp.setActivationPolicy(.prohibited)
      ConfigWindowController.numberOfConfigWindows = 0
    }
    return false
  }
}
