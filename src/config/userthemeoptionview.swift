import SwiftUI
import UniformTypeIdentifiers

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: UserThemeOption
  @State private var openPanel = NSOpenPanel()

  var body: some View {
    Button {
      selectFile(
        openPanel, themeDir, [UTType.init(filenameExtension: "conf")!],
        { fileName in
          model.value = String(fileName.dropLast(5))
        })
    } label: {
      if model.value.isEmpty {
        Text("Select/Import theme")
      } else {
        Text(model.value)
      }
    }
  }
}
