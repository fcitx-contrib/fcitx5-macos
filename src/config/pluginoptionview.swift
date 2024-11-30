import Logging
import SwiftUI

struct PluginOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: PluginOption
  @State private var availablePlugins = [String]()

  var body: some View {
    Picker("", selection: $model.value) {
      ForEach(availablePlugins, id: \.self) { plugin in
        Text(plugin)
      }
    }.onAppear {
      for fileName in getFileNamesWithExtension(jsPluginDir.localPath()) {
        let url = jsPluginDir.appendingPathComponent(fileName)
        if !url.isDirectory {
          continue
        }
        let packageJsonURL = url.appendingPathComponent("package.json")
        if let json = readJSON(packageJsonURL) {
          if json["license"].stringValue.hasPrefix("GPL-3.0") {
            availablePlugins.append(fileName)
          } else {
            FCITX_WARN("Rejecting plugin \(fileName) which is not GPLv3")
          }
        } else {
          FCITX_WARN("Invalid package.json for plugin \(fileName)")
        }
      }
    }
  }
}
