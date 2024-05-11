import SwiftUI

private let dataDir = extractDir.appendingPathComponent("external")

struct ImportableItem: Identifiable {
  let id = UUID()
  var name: String
  var enabled: Bool
  var exists: () -> Bool
  var doImport: () -> Bool
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
      dataDir.appendingPathComponent("data/pinyin/customphrase").exists()
    },
    doImport: {
      mkdirP(customphrasePath)
      return moveAndMerge(
        dataDir.appendingPathComponent("data/pinyin/customphrase"),
        customphrase)
    }),
  ImportableItem(
    name: NSLocalizedString("Dictionaries", comment: ""), enabled: true,
    exists: {
      getFileNamesWithExtension(
        dataDir.appendingPathComponent("data/pinyin/dictionaries").localPath(), ".dict"
      ).count > 0
    },
    doImport: {
      mkdirP(dictPath)
      return moveAndMerge(
        dataDir.appendingPathComponent("data/pinyin/dictionaries"),
        dictDir)
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
