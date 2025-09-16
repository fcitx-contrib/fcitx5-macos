import Fcitx
import SwiftUI
import SwiftyJSON

// Should only list Apps that are not available in App selector.
private let presetApps: [String] = [
  "/System/Library/CoreServices/Spotlight.app",
  "/System/Library/Input Methods/CharacterPalette.app",  // emoji picker
]

struct AppIMOptionView: OptionView {
  let label: String
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
    let openPanel = NSOpenPanel()  // macOS 26 crashes if put outside of body.
    HStack {
      if !model.appPath.isEmpty {
        appIconFromPath(model.appPath)
      }
      Picker("", selection: $model.appPath) {
        ForEach(selections(), id: \.self) { key in
          if key.isEmpty {
            Text("Select App")
          } else {
            HStack {
              if model.appPath != key {
                appIconFromPath(key)
              }
              Text(appNameFromPath(key)).tag(key)
            }
          }
        }
      }
      Button {
        selectApplication(
          openPanel,
          onFinish: { path in
            model.appPath = path
          })
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
}
