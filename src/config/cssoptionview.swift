import SwiftUI
import UniformTypeIdentifiers

private let cssDir = wwwDir.appendingPathComponent("css")
private let fcitxPrefix = "fcitx:///file/css/"

struct CssOptionView: OptionView {
  let label: String
  @ObservedObject var model: CssOption

  var body: some View {
    SelectFileButton(
      directory: cssDir,
      allowedContentTypes: [UTType.init(filenameExtension: "css")!],
      onFinish: { fileName in
        if !fileName.isEmpty {
          model.value = fcitxPrefix + fileName
        }
      },
      label: {
        if !model.value.hasPrefix(fcitxPrefix) {
          Text("Select/Import CSS")
        } else {
          Text(model.value.dropFirst(fcitxPrefix.count))
        }
      }, model: $model.value
    )
  }
}
