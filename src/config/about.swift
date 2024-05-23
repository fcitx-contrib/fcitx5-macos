import Carbon
import Logging
import SwiftUI

let sourceRepo = "https://github.com/fcitx-contrib/fcitx5-macos"
let updateLog = "/tmp/Fcitx5Update.log"
let uninstallLog = "/tmp/Fcitx5Uninstall.log"

func getDate() -> String {
  let dateFormatter = DateFormatter()
  dateFormatter.dateStyle = .medium
  dateFormatter.timeStyle = .medium
  dateFormatter.locale = Locale.current
  return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(unixTime)))
}

func urlButton(_ text: String, _ link: String) -> some View {
  Button(
    action: {
      if let url = URL(string: link) {
        NSWorkspace.shared.open(url)
      }
    },
    label: {
      Text(text)
        .foregroundColor(.blue)
    }
  ).buttonStyle(PlainButtonStyle())
    .focusable(false)
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
  case checkFailedSheet  // to notChecked
  case upToDateSheet  // to upToDate
  case upToDate  // Disabled "Check update", reset to notChecked on refresh
  case availableSheet  // to available or downloading
  case available  // Clickable "Update"
  case downloading  // Disabled "Update"
  case downloadFailedSheet  // to available
  case installing  // Disabled "Update"
  case installFailedSheet  // to available
}

struct AboutView: View {
  // @State won't work as it doesn't update view when the value is changed in refresh().
  @ObservedObject private var viewModel = ViewModel()
  @State private var downloadProgress = 0.0

  @State private var confirmUninstall = false
  @State private var removeUserData = false
  @State private var uninstallFailed = false

  var body: some View {
    VStack {
      if let iconURL = Bundle.main.url(forResource: "fcitx", withExtension: "icns"),
        let icon = NSImage(contentsOf: iconURL)
      {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 80, height: 80)
      }
      Text("Fcitx5 macOS")
        .font(.title)

      Spacer().frame(height: gapSize)
      Text(arch)

      Spacer().frame(height: gapSize)
      urlButton(String(commit.prefix(7)), sourceRepo + "/commit/" + commit)

      Spacer().frame(height: gapSize)
      Text(getDate())

      Spacer().frame(height: gapSize)
      HStack {
        Text(NSLocalizedString("Originally made by", comment: ""))
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
        Button(
          action: {
            if viewModel.state == .notChecked {
              checkUpdate()
            } else if viewModel.state == .available {
              update()
            }
          },
          label: {
            if viewModel.state == .notChecked || viewModel.state == .upToDate {
              Text("Check update")
            } else if viewModel.state == .checking || viewModel.state == .checkFailedSheet
              || viewModel.state == .upToDateSheet || viewModel.state == .availableSheet
            {
              Text("Checking")
            } else {
              Text("Update")
            }
          }
        ).buttonStyle(.borderedProminent)
          .disabled(
            viewModel.state == .checking || viewModel.state == .upToDate
              || viewModel.state == .downloading || viewModel.state == .installing
          )
          .sheet(
            isPresented: $viewModel.showCheckFailed,
            onDismiss: {
              viewModel.state = .notChecked
            }
          ) {
            VStack {
              Text("Failed to check update")
              Button(
                action: {
                  viewModel.state = .notChecked
                },
                label: {
                  Text("OK")
                }
              ).buttonStyle(.borderedProminent)
            }.padding()
          }
          .sheet(
            isPresented: $viewModel.showUpToDate,
            onDismiss: {
              viewModel.state = .upToDate
            }
          ) {
            VStack {
              Text("Fcitx5 is up to date")
              Button(
                action: {
                  viewModel.state = .upToDate
                },
                label: {
                  Text("OK")
                }
              ).buttonStyle(.borderedProminent)
            }.padding()
          }
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
              Button(
                action: {
                  update()
                },
                label: {
                  Text("Update now")
                }
              ).buttonStyle(.borderedProminent)
              Button(
                action: {
                  viewModel.state = .available
                },
                label: {
                  Text("Maybe later")
                }
              )
            }.padding()
          }
          .sheet(
            isPresented: $viewModel.showDownloadFailed,
            onDismiss: {
              viewModel.state = .available
            }
          ) {
            VStack {
              Text("Download failed")
              Button(
                action: {
                  viewModel.state = .available
                },
                label: {
                  Text("OK")
                }
              ).buttonStyle(.borderedProminent)
            }.padding()
          }
          .sheet(
            isPresented: $viewModel.showInstallFailed,
            onDismiss: {
              viewModel.state = .available
            }
          ) {
            VStack {
              Text("Install failed")
              Button(
                action: {
                  viewModel.state = .available
                },
                label: {
                  Text("OK")
                }
              ).buttonStyle(.borderedProminent)
            }.padding()
          }

        Button(
          action: {
            confirmUninstall = true
          },
          label: {
            Text("Uninstall")
          }
        ).sheet(
          isPresented: $confirmUninstall
        ) {
          VStack {
            Text("Are you sure to uninstall?")
            Button(
              action: {
                confirmUninstall = false
              },
              label: {
                Text("Cancel")
              })
            Button(
              action: {
                removeUserData = false
                uninstall()
              },
              label: {
                Text("Uninstall and keep user data")
              })
            Button(
              action: {
                removeUserData = true
                uninstall()
              },
              label: {
                Text("Uninstall")
              })
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
            Button(
              action: {
                uninstallFailed = false
              },
              label: {
                Text("OK")
              }
            ).buttonStyle(.borderedProminent)
          }.padding()
        }
      }
      if viewModel.state == .downloading {
        ProgressView(value: downloadProgress, total: 1)
      }
    }.padding()
  }

  func uninstall() {
    confirmUninstall = false
    // It's necessary to disable not only for cleaning up.
    // Without this, if user cancels sudo prompt and try again, UI will hang.
    disableInputMethod()
    if !sudo("uninstall", removeUserData ? "true" : "false", uninstallLog) {
      uninstallFailed = true
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
          viewModel.state = .upToDateSheet
        } else {
          viewModel.state = .availableSheet
        }
      } else {
        viewModel.state = .checkFailedSheet
      }
    }.resume()
  }

  func update() {
    viewModel.state = .downloading
    checkPluginUpdate({ plugins in
      let pluginUrlMap = plugins.reduce(into: [String: String]()) { result, plugin in
        result[plugin] = getPluginAddress(plugin)
      }
      let fileName = "Fcitx5-\(arch).tar.bz2"
      let address = "\(sourceRepo)/releases/download/latest/\(fileName)"
      let downloader = Downloader(Array(pluginUrlMap.values) + [address])
      downloader.download(
        onFinish: { results in
          // Install plugin in a best-effort manner. No need to over-engineering.
          for plugin in plugins {
            let result = results[pluginUrlMap[plugin]!]!
            if result {
              extractPlugin(plugin)
            }
          }
          // Install main
          if results[address]! {
            install(cacheDir.appendingPathComponent(fileName).localPath())
          } else {
            viewModel.state = .downloadFailedSheet
          }
        },
        onProgress: { progress in
          downloadProgress = progress
        })
    })
  }

  func install(_ path: String) {
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
    // Necessary to put it in background, otherwise sudo UI will hang if it has been canceled once.
    DispatchQueue.global().async {
      if !sudo("update", path, updateLog) {
        DispatchQueue.main.async {
          viewModel.state = .installFailedSheet
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
        showCheckFailed = false
        showUpToDate = false
        showAvailable = false
        showDownloadFailed = false
        showInstallFailed = false
        if state == .checkFailedSheet {
          showCheckFailed = true
        } else if state == .upToDateSheet {
          showUpToDate = true
        } else if state == .availableSheet {
          showAvailable = true
        } else if state == .downloadFailedSheet {
          showDownloadFailed = true
        } else if state == .installFailedSheet {
          showInstallFailed = true
        }
      }
    }
    @Published var showCheckFailed: Bool = false
    @Published var showUpToDate: Bool = false
    @Published var showAvailable: Bool = false
    @Published var showDownloadFailed: Bool = false
    @Published var showInstallFailed: Bool = false

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
