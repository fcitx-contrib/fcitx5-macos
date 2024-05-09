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
      return dataDir.appendingPathComponent("config/config").exists()
    },
    doImport: {
      return moveAndMerge(
        dataDir.appendingPathComponent("config/config"),
        configDir.appendingPathComponent("config"))
    })
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
      }
      Button {
        for item in items {
          if item.enabled {
            item.doImport()
          }
        }
      } label: {
        Text("Import")
      }
    }.padding()
  }
}
