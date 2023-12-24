import Cocoa
import Fcitx
import InputMethodKit
import SwiftFcitx

class NSManualApplication: NSApplication {
  private let appDelegate = AppDelegate()

  override init() {
    super.init()
    self.delegate = appDelegate
  }

  required init?(coder: NSCoder) {
    fatalError("Unreachable path")
  }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  static var server = IMKServer()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)
    let candidates = IMKCandidates(
      server: AppDelegate.server,
      panelType: kIMKSingleColumnScrollingCandidatePanel)!
    // The default behavior is wrong: scrolling will assign 1-9 to 2nd-10th candidates.
    // But setting 10 virtual keyCodes doesn't work, so just disable it.
    candidates.setSelectionKeys([])
    setImkc(candidates)
    start_fcitx()
  }

  func applicationWillTerminate(_ notification: Notification) {
  }
}
