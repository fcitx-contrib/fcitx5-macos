import AlertToast
import SwiftUI

private let dataDir = extractDir.appendingPathComponent("external")
private let imDir = dataDir.appendingPathComponent("data/inputmethod")
private let pinyinDir = dataDir.appendingPathComponent("data/pinyin")
private let tableDir = dataDir.appendingPathComponent("data/table")
private let f5aRimeDir = dataDir.appendingPathComponent("data/rime")
let hamsterRimeDir = extractDir.appendingPathComponent("HamsterBackup/RIME/Rime")

struct ImportableItem: Identifiable {
  let id = UUID()
  var name: String
  var enabled: Bool
  var exists: () -> Bool
  var doImport: () -> Bool
}

private func rimeExcluded(_ rimeDir: URL) -> [String] {
  ["installation.yaml", "sync"]
}

private func rimeBin(_ rimeDir: URL) -> [String] {
  if rimeDir.appendingPathComponent("build").exists() {
    return ["build"]
  }
  return []
}

private func rimeUser(_ rimeDir: URL) -> [String] {
  var userFiles = getFileNamesWithExtension(rimeDir.localPath(), ".userdb", true)
  if rimeDir.appendingPathComponent("user.yaml").exists() {
    userFiles.append("user.yaml")
  }
  return userFiles
}

private func rimeConfig(_ rimeDir: URL) -> [String] {
  let allFiles = getFileNamesWithExtension(rimeDir.localPath())
  let otherFiles = [rimeExcluded, rimeBin, rimeUser].flatMap { $0(rimeDir) }
  return allFiles.filter { !otherFiles.contains($0) }
}

private func importRime(_ getter: (URL) -> [String], _ rimeDir: URL) -> Bool {
  mkdirP(rimeLocalDir.localPath())
  return getter(rimeDir).map { fileName in
    moveAndMerge(
      rimeDir.appendingPathComponent(fileName),
      rimeLocalDir.appendingPathComponent(fileName)
    )
  }.allSatisfy { $0 }
}

private func importableRimeConfig(_ rimeDir: URL) -> ImportableItem {
  return ImportableItem(
    name: NSLocalizedString("Rime config", comment: ""), enabled: true,
    exists: {
      rimeConfig(rimeDir).count > 0
    },
    doImport: {
      importRime(rimeConfig, rimeDir)
    })
}

private func importableRimeBin(_ rimeDir: URL) -> ImportableItem {
  return ImportableItem(
    name: NSLocalizedString("Rime binaries", comment: ""), enabled: false,
    exists: {
      rimeBin(rimeDir).count > 0
    },
    doImport: {
      importRime(rimeBin, rimeDir)
    })
}

private func importableRimeUser(_ rimeDir: URL) -> ImportableItem {
  return ImportableItem(
    name: NSLocalizedString("Rime user data", comment: ""), enabled: false,
    exists: {
      rimeUser(rimeDir).count > 0
    },
    doImport: {
      importRime(rimeUser, rimeDir)
    })
}

let squirrelItems = [
  importableRimeConfig(extractDir),
  importableRimeBin(extractDir),
  importableRimeUser(extractDir),
]

let hamsterItems = [
  importableRimeConfig(hamsterRimeDir),
  importableRimeBin(hamsterRimeDir),
  importableRimeUser(hamsterRimeDir),
]

let f5aItems = [
  ImportableItem(
    name: NSLocalizedString("Global Config", comment: ""), enabled: false,
    exists: {
      dataDir.appendingPathComponent("config/config").exists()
    },
    doImport: {
      mkdirP(configDir.localPath())
      return moveAndMerge(
        dataDir.appendingPathComponent("config/config"),
        configDir.appendingPathComponent("config"))
    }),
  ImportableItem(
    name: NSLocalizedString("Addon Config", comment: ""), enabled: true,
    exists: {
      getFileNamesWithExtension(dataDir.appendingPathComponent("config/conf").localPath(), ".conf")
        .filter { !$0.hasPrefix("android") }
        .count > 0
    },
    doImport: {
      // Don't import android-specific config
      for fileName in getFileNamesWithExtension(
        dataDir.appendingPathComponent("config/conf").localPath(), ".conf"
      )
      .filter({ $0.hasPrefix("android") }) {
        _ = removeFile(dataDir.appendingPathComponent("config/conf/\(fileName).conf"))
      }
      mkdirP(configDir.localPath())
      return moveAndMerge(
        dataDir.appendingPathComponent("config/conf"),
        configDir.appendingPathComponent("conf"))
    }),
  ImportableItem(
    name: NSLocalizedString("Quick Phrase", comment: ""), enabled: true,
    exists: {
      getFileNamesWithExtension(
        dataDir.appendingPathComponent("data/data/quickphrase.d").localPath(), ".mb"
      ).count > 0
    },
    doImport: {
      mkdirP(localQuickphrasePath)
      return moveAndMerge(
        dataDir.appendingPathComponent("data/data/quickphrase.d"),
        localQuickphraseDir)
    }),
  ImportableItem(
    name: NSLocalizedString("Custom Phrase", comment: ""), enabled: true,
    exists: {
      pinyinDir.appendingPathComponent("customphrase").exists()
    },
    doImport: {
      mkdirP(pinyinPath)
      return moveAndMerge(
        pinyinDir.appendingPathComponent("customphrase"),
        customphrase)
    }),
  ImportableItem(
    name: NSLocalizedString("Pinyin Dictionaries", comment: ""), enabled: true,
    exists: {
      getFileNamesWithExtension(
        pinyinDir.appendingPathComponent("dictionaries").localPath(), ".dict"
      ).count > 0
    },
    doImport: {
      mkdirP(dictPath)
      return moveAndMerge(
        pinyinDir.appendingPathComponent("dictionaries"),
        dictDir)
    }),
  ImportableItem(
    name: NSLocalizedString("Pinyin user data", comment: ""), enabled: false,
    exists: {
      ["user.dict", "user.history"].contains { fileName in
        pinyinDir.appendingPathComponent(fileName).exists()
      }
    },
    doImport: {
      mkdirP(pinyinLocalDir.localPath())
      return ["user.dict", "user.history"].map { fileName in
        let url = pinyinDir.appendingPathComponent(fileName)
        return !url.exists() || moveAndMerge(url, pinyinLocalDir.appendingPathComponent(fileName))
      }.allSatisfy { $0 }
    }),
  ImportableItem(
    name: NSLocalizedString("Table", comment: ""), enabled: true,
    exists: {
      getFileNamesWithExtension(tableDir.localPath()).count > 0
    },
    doImport: {
      mkdirP(imLocalDir.localPath())
      mkdirP(tableLocalDir.localPath())
      return [
        moveAndMerge(tableDir, tableLocalDir),
        !imDir.exists() || moveAndMerge(imDir, imLocalDir),
      ]
      .allSatisfy { $0 }
    }
  ),
  importableRimeConfig(f5aRimeDir),
  importableRimeBin(f5aRimeDir),
  importableRimeUser(f5aRimeDir),
]

let f5mItems = [
  ImportableItem(
    name: NSLocalizedString("Config", comment: ""), enabled: true,
    exists: {
      dataDir.appendingPathComponent("config").exists()
    },
    doImport: {
      mkdirP(configDir.localPath())
      return moveAndMerge(dataDir.appendingPathComponent("config"), configDir)
    }),
  ImportableItem(
    name: NSLocalizedString("Data", comment: ""), enabled: true,
    exists: {
      dataDir.appendingPathComponent("data").exists()
    },
    doImport: {
      mkdirP(localDir.localPath())
      return moveAndMerge(
        dataDir.appendingPathComponent("data"), localDir)
    }),
]

class ImportDataVM: ObservableObject {
  @Published var importableItems = [ImportableItem]()
  @Published var items = [ImportableItem]()

  func refresh(_ importableItems: [ImportableItem]) {
    self.importableItems = importableItems
    self.items = importableItems.filter { $0.exists() }
  }
}

struct ImportDataView: View {
  @Environment(\.presentationMode) var presentationMode

  @ObservedObject private var importDataVM = ImportDataVM()
  @State private var failedItems = [String]()
  @State private var showAlert = false
  @State private var showSuccess = false

  func load(_ importableItems: [ImportableItem]) -> some View {
    importDataVM.refresh(importableItems)
    return self
  }

  var body: some View {
    VStack {
      Text("Files with the same name will be overridden.")
      List {
        ForEach($importDataVM.items) { $item in
          Toggle(item.name, isOn: $item.enabled)
        }
      }.frame(minWidth: 300, minHeight: 200)
      HStack {
        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Done")
        }
        Button {
          failedItems = [String]()
          restartAndReconnect({
            for item in importDataVM.items {
              if item.enabled {
                if !item.doImport() {
                  failedItems.append(item.name)
                }
              }
            }
          })
          importDataVM.refresh(importDataVM.importableItems)
          if failedItems.isEmpty {
            showSuccess = true
          } else {
            showAlert = true
          }
        } label: {
          Text("Import")
        }.buttonStyle(.borderedProminent)
          .disabled(importDataVM.items.allSatisfy { !$0.enabled })
          .alert(
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
            Text(
              NSLocalizedString("Items failed to import:", comment: "")
                + failedItems.joined(separator: ", "))
          }
      }
    }.padding()
      .toast(isPresenting: $showSuccess) {
        AlertToast(
          displayMode: .hud,
          type: .complete(Color.green), title: NSLocalizedString("Import succeeded", comment: ""))
      }
  }
}
