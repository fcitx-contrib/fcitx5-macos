import Logging
import SwiftUI
import UniformTypeIdentifiers

let extractDir = cacheDir.appendingPathComponent("import")
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
  return extractDir.appendingPathComponent("metadata.json").exists()
}

struct AdvancedView: View {
  let openPanel = NSOpenPanel()
  @AppStorage("ImportDataSelectedDirectory") var importDataSelectedDirectory: String?
  @State private var showImportF5a = false
  @State private var showImportSquirrel = false

  var body: some View {
    VStack {
      Text("Import data from …")

      Button {
        removeFile(extractDir)
        if copyFile(squirrelDir, extractDir) {
          showImportSquirrel = true
        }
      } label: {
        Text("Local Squirrel")
      }.sheet(isPresented: $showImportSquirrel) {
        ImportDataView(squirrelItems)
      }.disabled(!FileManager.default.fileExists(atPath: squirrelDir.localPath()))

      Button {
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [UTType.init(filenameExtension: "zip")!]
        openPanel.directoryURL = URL(
          fileURLWithPath: importDataSelectedDirectory
            ?? homeDir.appendingPathComponent("Downloads").localPath())
        openPanel.begin { response in
          if response == .OK {
            removeFile(extractDir)
            mkdirP(extractPath)
            if let file = openPanel.urls.first, extractZip(file) {
              showImportF5a = true
            }
          }
          importDataSelectedDirectory = openPanel.directoryURL?.localPath()
        }
      } label: {
        Text("Fcitx5 Android")
      }.sheet(isPresented: $showImportF5a) {
        ImportDataView(f5aItems)
      }
    }.padding()
  }
}
