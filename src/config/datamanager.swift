import AlertToast
import SwiftUI
import UniformTypeIdentifiers

let extractDir = cacheDir.appendingPathComponent("import")
let extractPath = extractDir.localPath()
let composeDir = cacheDir.appendingPathComponent("export")

private func extractZip(_ file: URL) -> Bool {
  // unzip is unfriendly with Chinese file names
  return exec("/usr/bin/ditto", ["-xk", file.localPath(), extractPath])
}

private func getTimeString() -> String {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH_mm_ss'Z'"
  dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
  dateFormatter.locale = Locale(identifier: "en_US_POSIX")
  return dateFormatter.string(from: Date())
}

struct DataView: View {
  @State private var openPanel = NSOpenPanel()
  @AppStorage("ImportDataSelectedDirectory") var importDataSelectedDirectory: String?
  @AppStorage("ExportDataSelectedDirectory") var exportDataSelectedDirectory: String?
  @State private var showImportF5a = false
  @State private var showImportF5m = false
  @State private var showImportSquirrel = false
  @State private var showImportHamster = false
  @State private var showSquirrelError = false
  @State private var showInvalidZip = false
  @State private var showRunning = false
  @State private var showExportSuccess = false
  @State private var showExportFailure = false

  private func importZip(_ binding: Binding<Bool>, _ validator: @escaping () -> Bool) {
    // Keep a single openPanel to avoid confusion.
    if openPanel.isVisible {
      openPanel.cancel(nil)
      openPanel = NSOpenPanel()
    }
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.allowedContentTypes = [.zip]
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

  private func exportZip(_ name: String) -> Bool {
    _ = removeFile(composeDir)
    // Fake f5a structure.
    for name in ["databases", "external", "recently_used", "shared_prefs"] {
      mkdirP(composeDir.appendingPathComponent(name).localPath())
    }
    let externalDir = composeDir.appendingPathComponent("external")
    for operation in [
      { copyFile(configDir, externalDir.appendingPathComponent("config")) },
      { copyFile(localDir, externalDir.appendingPathComponent("data")) },
      {
        writeUTF8(
          composeDir.appendingPathComponent("metadata.json"),
          """
          {
              "packageName": "org.fcitx.fcitx5.android",
              "versionCode": 0,
              "versionName": "",
              "exportTime": \(Int(Date().timeIntervalSince1970 * 1000))
          }\n
          """)
      },
      {
        exec(
          "/bin/zsh",
          [
            "-c",
            "cd \(quote(composeDir.localPath())) && /usr/bin/zip -r \(name) * -x \"*.DS_Store\"",
          ])
      },
    ] {
      if !operation() {
        return false
      }
    }
    return true
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
        ImportDataView().load(squirrelItems)
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
        ImportDataView().load(f5aItems)
      }

      Button {
        importZip(
          $showImportF5m,
          {
            extractDir.appendingPathComponent("metadata.json").exists()
          })
      } label: {
        Text("Fcitx5 macOS").tooltip("fcitx5-macos_YYYY-MM-DD*.zip")
      }.sheet(isPresented: $showImportF5m) {
        ImportDataView().load(f5mItems)
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
        ImportDataView().load(hamsterItems)
      }

      Spacer().frame(height: gapSize)

      Text("Export data to …")

      Button {
        showRunning = true
        let name = "fcitx5-macos_\(getTimeString()).zip"
        DispatchQueue.global().async {
          let res = exportZip(name)
          DispatchQueue.main.async {
            showRunning = false
            if res {
              if openPanel.isVisible {
                openPanel.cancel(nil)
                openPanel = NSOpenPanel()
              }
              openPanel.allowsMultipleSelection = false
              openPanel.canChooseDirectories = true
              openPanel.canChooseFiles = false
              if openPanel.runModal() == .OK {
                if let url = openPanel.url {
                  if moveFile(
                    composeDir.appendingPathComponent(name), url.appendingPathComponent(name))
                  {
                    showExportSuccess = true
                  } else {
                    showExportFailure = true
                  }
                  exportDataSelectedDirectory = url.localPath()
                }
              }
            } else {
              showExportFailure = true
            }
          }
        }
      } label: {
        Text("Fcitx5 Android/macOS")
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
      .toast(isPresenting: $showExportSuccess) {
        AlertToast(
          displayMode: .hud,
          type: .complete(Color.green), title: NSLocalizedString("Export succeeded", comment: ""))
      }
      .toast(isPresenting: $showExportFailure) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Export failed", comment: ""))
      }
      .toast(
        isPresenting: $showRunning
      ) {
        AlertToast(type: .loading)
      }
  }
}
