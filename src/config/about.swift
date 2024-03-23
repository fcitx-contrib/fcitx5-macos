import Carbon
import SwiftUI

let sourceRepo = "https://github.com/fcitx-contrib/fcitx5-macos"
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

struct AboutView: View {
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
      Text(getArch())

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
    }.padding()
  }

  func uninstall() {
    confirmUninstall = false
    disableInputMethod()
    if !sudo("uninstall", removeUserData ? "true" : "false", uninstallLog) {
      uninstallFailed = true
    }
  }
}

class FcitxAbout: ConfigWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: AboutView())
    window.center()
    self.init(window: window)
  }
}
