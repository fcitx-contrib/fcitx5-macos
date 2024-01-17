import Cocoa
import Fcitx

extension FcitxInputController {
  static var fcitxAbout: NSWindowController?

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
