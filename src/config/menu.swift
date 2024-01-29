import Cocoa
import Fcitx

extension FcitxInputController {
  static var fcitxAbout: NSWindowController?
  static var pluginManager: PluginManager?

  @objc func plugin(_: Any? = nil) {
    if FcitxInputController.pluginManager == nil {
      FcitxInputController.pluginManager = PluginManager()
    }
    FcitxInputController.pluginManager!.refreshPlugins()
    FcitxInputController.pluginManager!.showWindow(nil)
  }

  @objc func restart(_: Any? = nil) {
    restart_fcitx_thread()
  }

  @objc func about(_: Any? = nil) {
    if FcitxInputController.fcitxAbout == nil {
      FcitxInputController.fcitxAbout = FcitxAbout()
    }
    FcitxInputController.fcitxAbout!.showWindow(nil)
  }
}
