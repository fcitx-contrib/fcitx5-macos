import SwiftUI
import SwiftyJSON
import Logging

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

  func selectImage() {
    // Only consider the first image, but allow multiple deletion.
    openPanel.allowsMultipleSelection = true
    openPanel.canChooseDirectories = false
    openPanel.allowedContentTypes = [.image]
    openPanel.directoryURL = imageDir
    openPanel.begin { response in
      if response == .OK {
        guard let file = openPanel.urls.first else {
          return
        }
        var fileName = file.lastPathComponent
        if !imageDir.contains(file) {
          if !copyFile(file, imageDir.appendingPathComponent(fileName)) {
            return
          }
        } else {
          // Need to consider subdirectory of www/img.
          fileName = String(file.localPath().dropFirst(imageDir.localPath().count))
        }
        model.file = fileName
      }
    }
  }

  var body: some View {
    VStack {
      Picker("", selection: $model.mode) {
        ForEach(0..<modes.count) { idx in
          Text(modes[idx])
        }
      }
      if model.mode == 0 {
        Button {
          selectImage()
        } label: {
          if model.file.isEmpty {
            Text("Select image")
          } else {
            Text(model.file)
          }
        }
      } else {
        TextField("https:// or data:image/png;base64,", text: $model.url)
      }
    }
  }
}
