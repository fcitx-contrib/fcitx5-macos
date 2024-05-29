import Cocoa
import Fcitx

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
  static var fcitxAbout: FcitxAboutController = {
    return FcitxAboutController()
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
  static var themeEditorController: ThemeEditorController = {
    return ThemeEditorController()
  }()
  static var addonConfigController: AddonConfigController = {
    return AddonConfigController()
  }()
  static var advancedController: AdvancedController = {
    return AdvancedController()
  }()

  @objc func plugin(_: Any? = nil) {
    FcitxInputController.pluginManager.refreshPlugins()
    FcitxInputController.pluginManager.showWindow(nil)
  }

  @objc func restart(_: Any? = nil) {
    restartProcess()
  }

  @objc func about(_: Any? = nil) {
    FcitxInputController.fcitxAbout.refresh()
    FcitxInputController.fcitxAbout.showWindow(nil)
  }

  @objc func globalConfig(_: Any? = nil) {
    FcitxInputController.globalConfigController.showWindow(nil)
  }

  @objc func inputMethod(_: Any? = nil) {
    FcitxInputController.inputMethodConfigController.refresh()
    FcitxInputController.inputMethodConfigController.showWindow(nil)
  }

  @objc func themeEditor(_: Any? = nil) {
    FcitxInputController.themeEditorController.refresh()
    FcitxInputController.themeEditorController.showWindow(nil)
  }

  @objc func addonConfig(_: Any? = nil) {
    FcitxInputController.addonConfigController.refresh()
    FcitxInputController.addonConfigController.showWindow(nil)
  }

  @objc func advanced(_: Any? = nil) {
    FcitxInputController.advancedController.showWindow(nil)
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
    ConfigWindowController.numberOfConfigWindows -= 1

    // Switch back.
    if ConfigWindowController.numberOfConfigWindows <= 0 {
      NSApp.setActivationPolicy(.prohibited)
      ConfigWindowController.numberOfConfigWindows = 0
    }
    return false
  }
}
