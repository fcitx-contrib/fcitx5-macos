import SwiftUI
import UniformTypeIdentifiers

private let cssDir = wwwDir.appendingPathComponent("css")
private let fcitxPrefix = "fcitx:///file/css/"

struct CssOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: CssOption
  @State private var openPanel = NSOpenPanel()

  var body: some View {
    Button {
      selectFile(
        openPanel, cssDir, [UTType.init(filenameExtension: "css")!],
        { fileName in
          if fileName.isEmpty {
            model.value = ""
          } else {
            model.value = fcitxPrefix + fileName
          }
        })
    } label: {
      if !model.value.hasPrefix(fcitxPrefix) {
        Text("Select/Import CSS")
      } else {
        Text(model.value.dropFirst(fcitxPrefix.count))
      }
    }
  }
}
