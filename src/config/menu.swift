import Cocoa

extension FcitxInputController {
  static var fcitxAbout: NSWindowController?

  @objc func about(_: Any? = nil) {
    if FcitxInputController.fcitxAbout == nil {
      FcitxInputController.fcitxAbout = FcitxAbout()
    }
    FcitxInputController.fcitxAbout!.showWindow(nil)
  }
}
