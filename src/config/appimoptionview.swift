import Fcitx
import SwiftUI
import SwiftyJSON

// Should only list Apps that are not available in App selector.
private let presetApps: [String] = [
  "/System/Library/CoreServices/Spotlight.app",
  "/System/Library/Input Methods/CharacterPalette.app",  // emoji picker
]

private func image(_ appPath: String) -> Image {
  let icon = NSWorkspace.shared.icon(forFile: appPath)
  return Image(nsImage: icon)
}

struct AppIMOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  let openPanel = NSOpenPanel()
  @ObservedObject var model: AppIMOption
  @State private var appIcon: NSImage? = nil
  @State private var imNameMap: [String: String] = [:]

  func selections() -> [String] {
    if model.appPath.isEmpty || presetApps.contains(model.appPath) {
      return [""] + presetApps
    }
    return [""] + [model.appPath] + presetApps
  }

  var body: some View {
    HStack {
      if !model.appPath.isEmpty {
        image(model.appPath)
      }
      Picker("", selection: $model.appPath) {
        ForEach(selections(), id: \.self) { key in
          if key.isEmpty {
            Text("Select App")
          } else {
            HStack {
              if model.appPath != key {
                image(key)
              }
              Text(appNameFromPath(key)).tag(key)
            }
          }
        }
      }
      Button {
        openSelector()
      } label: {
        Image(systemName: "folder")
      }
      Picker(
        NSLocalizedString("uses", comment: "App X *uses* some input method"),
        selection: $model.imName
      ) {
        ForEach(Array(imNameMap.keys), id: \.self) { key in
          Text(imNameMap[key] ?? "").tag(key)
        }
      }
    }.padding(.bottom, 8)
      .onAppear {
        imNameMap = [:]
        let curGroup = JSON(parseJSON: String(Fcitx.imGetCurrentGroup()))
        for (_, inputMethod) in curGroup {
          let imName = inputMethod["name"].stringValue
          let nativeName = inputMethod["displayName"].stringValue
          imNameMap[imName] = nativeName
        }
      }
  }

  private func openSelector() {
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.allowedContentTypes = [.application]
    openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
    openPanel.begin { response in
      if response == .OK {
        let selectedApp = openPanel.urls.first
        if let appURL = selectedApp {
          model.appPath = appURL.localPath()
        }
      }
    }
  }
}
