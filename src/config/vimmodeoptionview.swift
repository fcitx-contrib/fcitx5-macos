import SwiftUI

struct VimModeOptionView: OptionView {
  let label: String
  @ObservedObject var model: VimModeOption

  var body: some View {
    let openPanel = NSOpenPanel()  // macOS 26 crashes if put outside of body.
    HStack {
      let appPath = appPathFromBundleIdentifier(model.value)
      let appName = appNameFromPath(appPath)
      if !appPath.isEmpty {
        appIconFromPath(appPath)
      }
      Spacer()
      if !appName.isEmpty {
        Text(appName)
      } else if model.value.isEmpty {
        Text("Select App")
      } else {
        Text(model.value)
      }
      Button {
        selectApplication(
          openPanel,
          onFinish: { path in
            model.value = bundleIdentifier(path)
          })
      } label: {
        Image(systemName: "folder")
      }
    }
  }
}
