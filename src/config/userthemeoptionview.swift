import SwiftUI
import UniformTypeIdentifiers

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeOptionView: OptionView {
  let label: String
  @ObservedObject var model: UserThemeOption

  var body: some View {
    SelectFileButton(
      directory: themeDir,
      allowedContentTypes: [UTType.init(filenameExtension: "conf")!],
      onFinish: { fileName in
        model.value = String(fileName.dropLast(5))
      },
      label: {
        if model.value.isEmpty {
          Text("Select/Import theme")
        } else {
          Text(model.value)
        }
      }, model: $model.value
    )
  }
}
