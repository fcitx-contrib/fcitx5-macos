import SwiftUI

private let modes = [
  NSLocalizedString("Local", comment: ""),
  "URL",
]

private let imageDir = wwwDir.appendingPathComponent("img")

struct ImageOptionView: OptionView {
  let label: String
  @ObservedObject var model: ImageOption

  var body: some View {
    VStack(alignment: .leading) {  // Avoid layout shift of Picker when switching modes.
      Picker("", selection: $model.mode) {
        ForEach(Array(modes.enumerated()), id: \.0) { idx, mode in
          Text(mode)
        }
      }
      if model.mode == 0 {
        SelectFileButton(
          directory: imageDir,
          allowedContentTypes: [.image],
          onFinish: { fileName in
            model.file = fileName
          },
          label: {
            if model.file.isEmpty {
              Text("Select image")
            } else {
              Text(model.file)
            }
          }, model: $model.file
        )
      } else {
        TextField(
          NSLocalizedString("https:// or data:image/png;base64,", comment: ""), text: $model.url)
      }
    }
  }
}
