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

struct Object: Codable {
  let sha: String
}

struct Tag: Codable {
  let object: Object
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
  @State private var showCheckFailed = false
  @State private var showDownloadFailed = false
  @State private var showInstallFailed = false
  @State private var showUninstalled = false

  @State private var confirmUninstall = false
  @State private var removeUserData = false
  @State private var uninstalling = false
  @State private var uninstallFailed = false
  @State private var uninstalled = false

  var body: some View {
    VStack {
      if let iconURL = Bundle.main.url(forResource: "fcitx", withExtension: "icns"),
        let icon = NSImage(contentsOf: iconURL)
      {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 80, height: 80)
      }
      Text(String("Fcitx5 macOS"))  // no i18n by design
        .font(.title)

      Spacer().frame(height: gapSize)
      Text(arch)

      Spacer().frame(height: gapSize)
      urlButton(String(commit.prefix(7)), sourceRepo + "/commit/" + commit)

      Spacer().frame(height: gapSize)
      Text(getDate())

      Spacer().frame(height: gapSize)
      HStack {
        Text("Originally made by")
        urlButton("Qijia Liu", "https://github.com/eagleoflqj")
        Text("and")
        urlButton("ksqsf", "https://github.com/ksqsf")
      }

      Spacer().frame(height: gapSize)
      HStack {
        Text("Licensed under")
        urlButton("GPLv3", sourceRepo + "/blob/master/LICENSE")
      }

      Spacer().frame(height: gapSize)
      urlButton(
        NSLocalizedString("3rd-party source code", comment: ""),
        sourceRepo + "/blob/master/README.md#credits")

      Spacer().frame(height: gapSize)
      HStack {
        Button {
          if viewModel.state == .notChecked {
            checkUpdate()
          } else if viewModel.state == .available {
            update()
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
            uninstalled || viewModel.state == .checking || viewModel.state == .upToDate
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
              Text("Update available")
              Button {
                update()
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

        Button {
          confirmUninstall = true
        } label: {
          Text("Uninstall")
        }.disabled(uninstallFailed || uninstalled)
          .sheet(
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
      .toast(isPresenting: $showUninstalled) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Fcitx5 is uninstalled", comment: ""))
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
    DispatchQueue.global().async {
      if sudo("uninstall", removeUserData ? "true" : "false", uninstallLog) {
        DispatchQueue.main.async {
          uninstalling = false
          uninstalled = true
          showUninstalled = true
        }
      } else {
        DispatchQueue.main.async {
          uninstalling = false
          uninstallFailed = true
        }
      }
    }
  }

  func checkUpdate() {
    guard
      // https://api.github.com/repos/fcitx-contrib/fcitx5-macos/git/ref/tags/latest
      // GitHub API may be blocked in China and is unstable in general.
      let url = URL(
        string: "\(sourceRepo)/releases/download/latest/meta.json")
    else {
      return
    }
    viewModel.state = .checking
    URLSession.shared.dataTask(with: url) { data, response, error in
      if let data = data,
        let tag = try? JSONDecoder().decode(Tag.self, from: data)
      {
        if tag.object.sha == commit {
          viewModel.state = .upToDate
          showUpToDate = true
        } else {
          viewModel.state = .availableSheet
        }
      } else {
        viewModel.state = .notChecked
        showCheckFailed = true
      }
    }.resume()
  }

  func update() {
    viewModel.state = .downloading
    checkPluginUpdate({ success, nativePlugins, dataPlugins in
      let updater = Updater(main: true, nativePlugins: nativePlugins, dataPlugins: dataPlugins)
      updater.update(
        // Install plugin in a best-effort manner. No need to check plugin status.
        onFinish: { result, _, _ in
          if result {
            install()
          } else {
            viewModel.state = .available
            showDownloadFailed = true
          }
        },
        onProgress: { progress in
          downloadProgress = progress
        })
    })
  }

  func install() {
    viewModel.state = .installing
    switchOut()
    let path = cacheDir.appendingPathComponent(mainFileName).localPath()
    // Necessary to put it in background, otherwise sudo UI will hang if it has been canceled once.
    DispatchQueue.global().async {
      if sudo("update", path, updateLog) {
        DispatchQueue.main.async {
          viewModel.state = .upToDate
          showUpToDate = true
        }
      } else {
        DispatchQueue.main.async {
          viewModel.state = .available
          showInstallFailed = true
        }
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

  func refresh() {
    view.refresh()
  }
}
