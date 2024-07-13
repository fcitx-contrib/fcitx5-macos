import SwiftUI

private let modes = [
  NSLocalizedString("Local", comment: ""),
  "URL",
]

private let imageDir = wwwDir.appendingPathComponent("img")

struct ImageOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: ImageOption
  @State private var openPanel = NSOpenPanel()

  var body: some View {
    VStack {
      Picker("", selection: $model.mode) {
        ForEach(Array(modes.enumerated()), id: \.0) { idx, mode in
          Text(mode)
        }
      }
      if model.mode == 0 {
        Button {
          selectFile(
            openPanel, imageDir, [.image],
            { fileName in
              model.file = fileName
            })
        } label: {
          if model.file.isEmpty {
            Text("Select image")
          } else {
            Text(model.file)
          }
        }
      } else {
        TextField(
          NSLocalizedString("https:// or data:image/png;base64,", comment: ""), text: $model.url)
      }
    }
  }
}
