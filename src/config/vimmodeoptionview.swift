import SwiftUI

struct VimModeOptionView: OptionView {
  let label: String
  let openPanel = NSOpenPanel()
  @ObservedObject var model: VimModeOption

  var body: some View {
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
