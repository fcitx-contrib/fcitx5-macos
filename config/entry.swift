import AppKit

private func redirectStderr() {
  let file = fopen("/tmp/Fcitx5ConfigTool.log", "w")
  if let file = file {
    dup2(fileno(file), STDERR_FILENO)
    fclose(file)
  }
}

@main
struct ConfigApp {
  static func main() {
    redirectStderr()

    let args = CommandLine.arguments

    var targetWindow = args.count > 1 ? args[1] : "About"
    if targetWindow != "Plugin" {
      targetWindow = "About"
    }

    let identifier = Bundle.main.bundleIdentifier!
    if NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 0 {
      let center = DistributedNotificationCenter.default()
      center.post(name: .init("\(notificationPrefix)\(targetWindow)"), object: nil)
      return
    }

    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    delegate.showWindow(targetWindow)
    NSApplication.shared.run()
  }
}
