import Logging
import SwiftUI
import UniformTypeIdentifiers

let extractDir = cacheDirectory.appendingPathComponent("import")
let extractPath = extractDir.localPath()

class AdvancedController: ConfigWindowController {
  let view = AdvancedView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Advanced", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }
}

private func extractZip(_ file: URL) -> Bool {
  // unzip is unfriendly with Chinese file names
  if !exec("/usr/bin/ditto", ["-xk", file.localPath(), extractPath]) {
    return false
  }
  return FileManager.default.fileExists(
    atPath: extractDir.appendingPathComponent("metadata.json").localPath())
}

struct AdvancedView: View {
  let openPanel = NSOpenPanel()
  @AppStorage("ImportDataSelectedDirectory") var importDataSelectedDirectory: String?
  @State private var showImport = false

  var body: some View {
    Button {
      openPanel.allowsMultipleSelection = false
      openPanel.canChooseDirectories = false
      openPanel.allowedContentTypes = [UTType.init(filenameExtension: "zip")!]
      openPanel.directoryURL = URL(
        fileURLWithPath: importDataSelectedDirectory ?? FileManager.default
          .homeDirectoryForCurrentUser.localPath() + "/Downloads")
      openPanel.begin { response in
        if response == .OK {
          removeFile(extractDir)
          mkdirP(extractPath)
          if let file = openPanel.urls.first, extractZip(file) {
            showImport = true
          }
        }
        importDataSelectedDirectory = openPanel.directoryURL?.localPath()
      }
    } label: {
      Text("Import data from Fcitx5 Android")
    }.sheet(isPresented: $showImport) {
      ImportDataView()
    }
    .padding()
  }
}
