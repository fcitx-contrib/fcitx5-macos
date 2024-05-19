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
  return exec("/usr/bin/ditto", ["-xk", file.localPath(), extractPath])
}

struct AdvancedView: View {
  @State private var openPanel = NSOpenPanel()
  @AppStorage("ImportDataSelectedDirectory") var importDataSelectedDirectory: String?
  @State private var showImportF5a = false
  @State private var showImportSquirrel = false
  @State private var showImportHamster = false
  @State private var showAlert = false

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
        removeFile(extractDir)
        mkdirP(extractPath)
        if let file = openPanel.urls.first, extractZip(file), validator() {
          binding.wrappedValue = true
        } else {
          showAlert = true
        }
      }
      importDataSelectedDirectory = openPanel.directoryURL?.localPath()
    }
  }

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
    }.alert(
      Text("Error"),
      isPresented: $showAlert,
      presenting: ()
    ) { _ in
      Button {
        showAlert = false
      } label: {
        Text("OK")
      }
      .buttonStyle(.borderedProminent)
    } message: { _ in
      Text("Invalid zip.")
    }.padding()
  }
}
