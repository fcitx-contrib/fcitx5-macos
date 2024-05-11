import SwiftUI

private let dataDir = extractDir.appendingPathComponent("external")
private let pinyinDir = dataDir.appendingPathComponent("data/pinyin")
private let rimeDir = dataDir.appendingPathComponent("data/rime")

struct ImportableItem: Identifiable {
  let id = UUID()
  var name: String
  var enabled: Bool
  var exists: () -> Bool
  var doImport: () -> Bool
}

private func rimeExcluded() -> [String] {
  ["installation.yaml", "sync"]
}

private func rimeBin() -> [String] {
  if rimeDir.appendingPathComponent("build").exists() {
    return ["build"]
  }
  return []
}

private func rimeUser() -> [String] {
  var userFiles = getFileNamesWithExtension(rimeDir.localPath(), ".userdb", true)
  if rimeDir.appendingPathComponent("user.yaml").exists() {
    userFiles.append("user.yaml")
  }
  return userFiles
}

private func rimeConfig() -> [String] {
  do {
    let allFiles = try FileManager.default.contentsOfDirectory(atPath: rimeDir.localPath())
    let otherFiles = [rimeExcluded, rimeBin, rimeUser].flatMap { $0() }
    return allFiles.filter { !otherFiles.contains($0) }
  } catch {
    return []
  }
}

private func importRime(_ getter: () -> [String]) -> Bool {
  mkdirP(rimeLocalDir.localPath())
  return getter().map { fileName in
    moveAndMerge(
      rimeDir.appendingPathComponent(fileName),
      rimeLocalDir.appendingPathComponent(fileName)
    )
  }.allSatisfy { $0 }
}

private let importableItems = [
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
        removeFile(dataDir.appendingPathComponent("config/conf/\(fileName).conf"))
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
      mkdirP(pinyinDir.localPath())
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
    name: NSLocalizedString("Rime config", comment: ""), enabled: true,
    exists: {
      rimeConfig().count > 0
    },
    doImport: {
      importRime(rimeConfig)
    }),
  ImportableItem(
    name: NSLocalizedString("Rime binaries", comment: ""), enabled: false,
    exists: {
      rimeBin().count > 0
    },
    doImport: {
      importRime(rimeBin)
    }),
  ImportableItem(
    name: NSLocalizedString("Rime user data", comment: ""), enabled: false,
    exists: {
      rimeUser().count > 0
    },
    doImport: {
      importRime(rimeUser)
    }),
]

struct ImportDataView: View {
  @State private var items = importableItems.filter { $0.exists() }
  var body: some View {
    VStack {
      Text("Files with the same name will be overridden.")
      List {
        ForEach($items) { $item in
          Toggle(item.name, isOn: $item.enabled)
        }
      }.frame(minHeight: 200)
      Button {
        restartAndReconnect({
          for item in items {
            if item.enabled {
              item.doImport()
            }
          }
        })
      } label: {
        Text("Import")
      }.buttonStyle(.borderedProminent)
        .disabled(items.allSatisfy { !$0.enabled })
    }.padding()
  }
}
