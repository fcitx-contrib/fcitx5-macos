import Cocoa
import Fcitx

extension FcitxInputController {
  static var fcitxAbout: NSWindowController = {
    return FcitxAbout()
  }()
  static var pluginManager: PluginManager = {
    return PluginManager()
  }()
  static var globalConfig: GlobalConfig = {
    return GlobalConfig()
  }()

  @objc func plugin(_: Any? = nil) {
    FcitxInputController.pluginManager.refreshPlugins()
    FcitxInputController.pluginManager.showWindow(nil)
  }

  @objc func restart(_: Any? = nil) {
    restart_fcitx_thread()
  }

  @objc func about(_: Any? = nil) {
    FcitxInputController.fcitxAbout.showWindow(nil)
  }

  @objc func globalConfig(_: Any? = nil) {
    FcitxInputController.globalConfig.showWindow(nil)
  }
}
