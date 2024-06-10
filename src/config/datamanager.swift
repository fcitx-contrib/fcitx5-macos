import AlertToast
import SwiftUI
import UniformTypeIdentifiers

let extractDir = cacheDir.appendingPathComponent("import")
let extractPath = extractDir.localPath()

private func extractZip(_ file: URL) -> Bool {
  // unzip is unfriendly with Chinese file names
  return exec("/usr/bin/ditto", ["-xk", file.localPath(), extractPath])
}

struct DataView: View {
  @State private var openPanel = NSOpenPanel()
  @AppStorage("ImportDataSelectedDirectory") var importDataSelectedDirectory: String?
  @State private var showImportF5a = false
  @State private var showImportSquirrel = false
  @State private var showImportHamster = false
  @State private var showSquirrelError = false
  @State private var showInvalidZip = false

  private func importZip(_ binding: Binding<Bool>, _ validator: @escaping () -> Bool) {
    // Keep a single openPanel to avoid confusion.
    if openPanel.isVisible {
      openPanel.cancel(nil)
      openPanel = NSOpenPanel()
    }
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.allowedContentTypes = [UTType.init(filenameExtension: "zip")!]
    openPanel.directoryURL = URL(
      fileURLWithPath: importDataSelectedDirectory
        ?? homeDir.appendingPathComponent("Downloads").localPath())
    openPanel.begin { response in
      if response == .OK {
        _ = removeFile(extractDir)
        mkdirP(extractPath)
        if let file = openPanel.urls.first, extractZip(file), validator() {
          binding.wrappedValue = true
        } else {
          showInvalidZip = true
        }
      }
      importDataSelectedDirectory = openPanel.directoryURL?.localPath()
    }
  }

  var body: some View {
    VStack {
      Text("Import data from …")

      Button {
        _ = removeFile(extractDir)
        mkdirP(cacheDir.localPath())
        if copyFile(squirrelDir, extractDir) {
          showImportSquirrel = true
        } else {
          showSquirrelError = true
        }
      } label: {
        Text("Local Squirrel")
      }.sheet(isPresented: $showImportSquirrel) {
        ImportDataView(squirrelItems)
      }.disabled(!FileManager.default.fileExists(atPath: squirrelDir.localPath()))

      Button {
        importZip(
          $showImportF5a,
          {
            extractDir.appendingPathComponent("metadata.json").exists()
          })
      } label: {
        Text("Fcitx5 Android").tooltip("fcitx5-android_YYYY-MM-DD*.zip")
      }.sheet(isPresented: $showImportF5a) {
        ImportDataView(f5aItems)
      }

      Button {
        importZip(
          $showImportHamster,
          {
            hamsterRimeDir.exists()
          })
      } label: {
        Text("Hamster").tooltip("YYYYMMDD-*.zip")
      }.sheet(isPresented: $showImportHamster) {
        ImportDataView(hamsterItems)
      }
    }.padding()
      .toast(isPresenting: $showSquirrelError) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to copy Squirrel files", comment: ""))
      }
      .toast(isPresenting: $showInvalidZip) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Invalid zip", comment: ""))
      }
  }
}
