import SwiftUI

let sourceRepo = "https://github.com/fcitx-contrib/fcitx5-macos"

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

struct AboutView: View {
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

      Spacer().frame(height: 10)
      Text(getArch())

      Spacer().frame(height: 10)
      urlButton(String(commit.prefix(7)), sourceRepo + "/commit/" + commit)

      Spacer().frame(height: 10)
      Text(getDate())

      Spacer().frame(height: 10)
      HStack {
        Text(NSLocalizedString("Originally made by", comment: ""))
        urlButton("Qijia Liu", "https://github.com/eagleoflqj")
        Text("and")
        urlButton("ksqsf", "https://github.com/ksqsf")
      }

      Spacer().frame(height: 10)
      HStack {
        Text("Licensed under")
        urlButton("GPLv3", sourceRepo + "/blob/master/LICENSE")
      }

      Spacer().frame(height: 10)
      urlButton(
        NSLocalizedString("3rd-party source code", comment: ""),
        sourceRepo + "/blob/master/README.md#credits")
    }.padding()
  }
}

class FcitxAbout: ConfigWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: AboutView())
    window.center()
    self.init(window: window)
  }
}
