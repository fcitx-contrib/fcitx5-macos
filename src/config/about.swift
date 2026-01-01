import AlertToast
import Carbon
import Logging
import SwiftUI

let updateLog = "/tmp/Fcitx5Update.log"
let uninstallLog = "/tmp/Fcitx5Uninstall.log"

func getDate() -> String {
  let dateFormatter = DateFormatter()
  dateFormatter.dateStyle = .medium
  dateFormatter.timeStyle = .medium
  dateFormatter.locale = Locale.current
  return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(unixTime)))
}

let bundleId = "org.fcitx.inputmethod.Fcitx5"
let inputSourceId = bundleId

func disableInputMethod() {
  let conditions = NSMutableDictionary()
  conditions.setValue(bundleId, forKey: kTISPropertyBundleID as String)
  // There are 2 items with kTISPropertyBundleID.
  // We disable the parent, which has kTISPropertyInputSourceID: org.fcitx.inputmethod.Fcitx5
  conditions.setValue(inputSourceId, forKey: kTISPropertyInputSourceID as String)
  if let array = TISCreateInputSourceList(conditions, true)?.takeRetainedValue()
    as? [TISInputSource]
  {
    for inputSource in array {
      TISDisableInputSource(inputSource)
    }
  }
}

enum UpdateState {
  case notChecked  // Clickable "Check update"
  case checking  // Disabled "Checking"
  case upToDate  // Disabled "Check update", reset to notChecked on refresh
  case availableSheet  // to available or downloading
  case available  // Clickable "Update"
  case downloading  // Disabled "Update"
  case installing  // Disabled "Update"
}

struct AboutView: View {
  // @State won't work as it doesn't update view when the value is changed in refresh().
  @ObservedObject private var viewModel = ViewModel()
  @State private var downloadProgress = 0.0

  @State private var showUpToDate = false
  @State private var showSystemNotSupported = false
  @State private var showCheckFailed = false
  @State private var showDownloadFailed = false
  @State private var showInstallFailed = false
  @State private var showSwitchToDebug = false
  @State private var confirmUninstall = false
  @State private var removeUserData = false
  @State private var uninstalling = false
  @State private var uninstallFailed = false
  // The value is based on check update, and is only used for upgrading to release.
  // If upgrading/switching to debug, always use latest regardless of this value.
  // If switching from latest debug to latest release, this value is nil.
  @State private var targetTag: String? = nil
  // If current version is latest, this is still true (for build type switch).
  @State private var latestAvailable = false

  var body: some View {
    VStack(spacing: gapSize) {
      if let iconURL = Bundle.main.url(forResource: "fcitx", withExtension: "icns"),
        let icon = NSImage(contentsOf: iconURL)
      {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 80, height: 80)
      }
      Text(String("Fcitx5 macOS"))  // no i18n by design
        .font(.title)

      HStack {
        Text(arch)
        if isDebug {
          Text("Debug")
        }
      }

      if releaseTag == "latest" {
        urlButton(String(commit.prefix(7)), sourceRepo + "/commit/" + commit)
      } else {
        urlButton(releaseTag, sourceRepo + "/tree/" + releaseTag)
      }

      Text(getDate())

      HStack {
        Text("Developed by")
        urlButton("Qijia Liu", "https://github.com/eagleoflqj")
        Text("and")
        urlButton("ksqsf", "https://github.com/ksqsf")
      }

      HStack {
        Text("Licensed under")
        urlButton("GPLv3", sourceRepo + "/blob/master/LICENSE")
      }

      urlButton(
        NSLocalizedString("3rd-party source code", comment: ""),
        sourceRepo + "/blob/master/README.md#credits")

      HStack {
        Button {
          if viewModel.state == .notChecked {
            checkUpdate()
          } else if viewModel.state == .available {
            update(debug: isDebug && targetTag == "latest")
          }
        } label: {
          if viewModel.state == .notChecked || viewModel.state == .upToDate {
            Text("Check update")
          } else if viewModel.state == .checking
            || viewModel.state == .availableSheet
          {
            Text("Checking")
          } else {
            Text("Update")
          }
        }.buttonStyle(.borderedProminent)
          .disabled(
            viewModel.state == .checking || viewModel.state == .upToDate
              || viewModel.state == .downloading || viewModel.state == .installing
          )
          .sheet(
            isPresented: $viewModel.showAvailable,
            onDismiss: {
              // Clicking "Update now" will also dismiss this sheet, and it happens before this.
              if viewModel.state == .availableSheet {
                viewModel.state = .available
              }
            }
          ) {
            VStack {
              if let tag = targetTag {  // Should always be true.
                if tag == "latest" {
                  Text("Latest (unstable) version available")
                } else {
                  Text("Version \(tag) available")
                }
              }
              Button {
                update(debug: isDebug && targetTag == "latest")
              } label: {
                Text("Update now")
              }.buttonStyle(.borderedProminent)
              Button {
                viewModel.state = .available
              } label: {
                Text("Maybe later")
              }
            }.padding()
          }

        if isDebug {
          Button {
            update(debug: false)
          } label: {
            Text("Switch to Release")
          }.disabled(
            (!latestAvailable
              && targetTag
                == nil  // We should always allow debug build to switch to release build,
                // so we drop OS version support only immediately after a new tag release.
                // Plus we don't provide debug build for tag release, this condition shouldn't be true.
                )
              || viewModel.state == .downloading || viewModel.state == .installing
          )
        } else {
          Button {
            showSwitchToDebug = true
          } label: {
            Text("Switch to Debug")
          }.disabled(
            !latestAvailable || viewModel.state == .downloading
              || viewModel.state == .installing
          ).sheet(
            isPresented: $showSwitchToDebug
          ) {
            VStack {
              Text("Switch to debug only if Fcitx5 crashes and you want to help debug.")
              HStack {
                Button {
                  showSwitchToDebug = false
                } label: {
                  Text("Cancel")
                }
                Button {
                  update(debug: true)
                  showSwitchToDebug = false
                } label: {
                  Text("OK")
                }.buttonStyle(.borderedProminent)
              }
            }.padding()
          }
        }

        Button {
          confirmUninstall = true
        } label: {
          Text("Uninstall")
        }.disabled(
          viewModel.state == .downloading || viewModel.state == .installing
        ).sheet(
          isPresented: $confirmUninstall
        ) {
          VStack {
            Text("Are you sure to uninstall?")
            Button {
              confirmUninstall = false
            } label: {
              Text("Cancel")
            }
            Button {
              removeUserData = false
              uninstall()
            } label: {
              Text("Uninstall and keep user data")
            }
            Button {
              removeUserData = true
              uninstall()
            } label: {
              Text("Uninstall")
            }
          }.padding()
        }.sheet(isPresented: $uninstallFailed) {
          VStack {
            Text("Uninstall failed, you may need to manually remove")
            Text("/Library/Input Methods/Fcitx5.app")
            Text("~/Library/fcitx5")
            Text("~/.config/fcitx5")
            if removeUserData {
              Text("~/.local/share/fcitx5")
            }
            Button {
              uninstallFailed = false
            } label: {
              Text("OK")
            }.buttonStyle(.borderedProminent)
          }.padding()
        }
      }
      if viewModel.state == .downloading {
        ProgressView(value: downloadProgress, total: 1)
      }
    }.padding()
      .toast(isPresenting: $showUpToDate) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Fcitx5 is up to date", comment: ""))
      }
      .toast(isPresenting: $showSystemNotSupported) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Your system version is no longer supported", comment: ""))
      }
      .toast(isPresenting: $showCheckFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to check update", comment: ""))
      }
      .toast(isPresenting: $showDownloadFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Download failed", comment: ""))
      }
      .toast(isPresenting: $showInstallFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Install failed", comment: ""))
      }
      .toast(
        isPresenting: Binding(
          get: { viewModel.state == .installing || uninstalling },
          set: { _ in }
        )
      ) {
        AlertToast(type: .loading)
      }
  }

  func uninstall() {
    confirmUninstall = false
    uninstalling = true
    // It's necessary to disable not only for cleaning up.
    // Without this, if user cancels sudo prompt and try again, UI will hang.
    disableInputMethod()
    let userDataParam = removeUserData ? "true" : "false"
    Task {
      let success = await Task.detached {
        sudo("uninstall", userDataParam, uninstallLog)
      }.value
      if !success {
        uninstalling = false
        uninstallFailed = true
      }
    }
  }

  func checkUpdate() {
    viewModel.state = .checking
    checkMainUpdate { success, latestCompatible, latest, stable in
      if success {
        latestAvailable = latestCompatible
        if let stable = stable {
          // latest >= stable > current
          targetTag = stable.tag
          viewModel.state = .availableSheet
        } else {
          if !latestCompatible {
            viewModel.state = .upToDate
            showSystemNotSupported = true
          } else if latest == nil {
            // latest == current >= stable
            viewModel.state = .upToDate
            showUpToDate = true
          } else {
            // latest > current >= stable
            targetTag = "latest"
            viewModel.state = .availableSheet
          }
        }
      } else {
        viewModel.state = .notChecked
        showCheckFailed = true
      }
    }
  }

  func update(debug: Bool) {
    // See comment of targetTag.
    guard
      let tag = getTag(
        currentDebug: isDebug, targetDebug: debug, latestAvailable: latestAvailable,
        targetTag: targetTag)
    else {
      FCITX_ERROR("Calling update with nil tag")
      return
    }
    viewModel.state = .downloading
    checkPluginUpdate(tag) { success, nativePlugins, dataPlugins in
      let updater = Updater(
        tag: tag, main: true, debug: debug, nativePlugins: nativePlugins, dataPlugins: dataPlugins)
      updater.update(
        // Install plugin in a best-effort manner. No need to check plugin status.
        onFinish: { result, _, _ in
          if result {
            install(debug: debug)
          } else {
            viewModel.state = .available
            showDownloadFailed = true
          }
        },
        onProgress: { progress in
          downloadProgress = progress
        })
    }
  }

  func install(debug: Bool) {
    viewModel.state = .installing
    let conditions = NSMutableDictionary()
    conditions.setValue("com.apple.keylayout.ABC", forKey: kTISPropertyInputSourceID as String)
    if let array = TISCreateInputSourceList(conditions, true)?.takeRetainedValue()
      as? [TISInputSource]
    {
      for inputSource in array {
        TISSelectInputSource(inputSource)
      }
    }
    let path = cacheDir.appendingPathComponent(debug ? mainDebugFileName : mainFileName).localPath()
    // Necessary to put it in background, otherwise sudo UI will hang if it has been canceled once.
    Task {
      let success = await Task.detached {
        sudo("update", path, updateLog)
      }.value
      if !success {
        viewModel.state = .available
        showInstallFailed = true
      }
    }
  }

  func refresh() {
    viewModel.refresh()
  }

  private class ViewModel: ObservableObject {
    @Published var state: UpdateState = .notChecked {
      didSet {
        showAvailable = state == .availableSheet
      }
    }
    @Published var showAvailable: Bool = false

    func refresh() {
      // Allow recheck update on reopen about.
      if state == .upToDate {
        state = .notChecked
      }
    }
  }
}

class FcitxAboutController: ConfigWindowController {
  let view = AboutView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }

  override func refresh() {
    view.refresh()
  }
}
