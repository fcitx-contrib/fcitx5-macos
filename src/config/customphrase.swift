import Fcitx
import SwiftUI
import UniformTypeIdentifiers

private let customphraseDir = localDir.appendingPathComponent("pinyin")
let customphrasePath = customphraseDir.localPath()

let customphrase = customphraseDir.appendingPathComponent("customphrase")

struct CustomPhrase: Identifiable {
  let id = UUID()
  var keyword: String
  var phrase: String
  var order: Int
}

private func parseLine(_ s: String) -> (CustomPhrase, Bool)? {
  let regex = try! NSRegularExpression(pattern: "(\\S+),(-?\\d+)=(.+)", options: [])
  let matches = regex.matches(
    in: s, options: [], range: NSRange(location: 0, length: s.utf16.count))

  if let match = matches.first {
    let keyword = String(s[Range(match.range(at: 1), in: s)!])
    let order = Int(String(s[Range(match.range(at: 2), in: s)!])) ?? 0
    let phrase = String(s[Range(match.range(at: 3), in: s)!])
    return (CustomPhrase(keyword: keyword, phrase: phrase, order: abs(order)), order > 0)
  }
  return nil
}

private func stringToCustomPhrases(_ s: String) -> [(CustomPhrase, Bool)] {
  return s.split(separator: "\n").compactMap { line in
    parseLine(String(line))
  }
}

private func customPhrasesToString(_ customphraseVM: CustomPhraseVM) -> String {
  return customphraseVM.customPhrases.map { customPhrase in
    "\(customPhrase.keyword),\(customphraseVM.isEnabled[customPhrase.id] ?? true ? "" : "-")\(customPhrase.order)=\(customPhrase.phrase)"
  }.joined(separator: "\n")
}

class CustomPhraseVM: ObservableObject {
  @Published var customPhrases: [CustomPhrase] = []
  @Published var isEnabled: [UUID: Bool] = [:]

  func refreshItems() {
    customPhrases = []
    isEnabled = [:]
    for (customPhrase, enabled) in stringToCustomPhrases(readUTF8(customphrase) ?? "") {
      customPhrases.append(customPhrase)
      isEnabled[customPhrase.id] = enabled
    }
  }
}

struct CustomPhraseView: View {
  let openPanel = NSOpenPanel()
  @AppStorage("CustomPhraseSelectedDirectory") var customPhraseSelectedDirectory: String?
  @State private var selectedRows = Set<UUID>()
  @ObservedObject private var customphraseVM = CustomPhraseVM()

  func refreshItems() -> some View {
    selectedRows = []
    customphraseVM.refreshItems()
    return self
  }

  func reloadCustomPhrase() {
    _ = refreshItems()
    Fcitx.setConfig("fcitx://config/addon/pinyin/customphrase", "{}")
  }

  var body: some View {
    HStack {
      List(selection: $selectedRows) {
        HStack {
          Text("").frame(width: checkboxColumnWidth)
          Text("Keyword").frame(
            minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
          Text("Phrase").frame(
            minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
          Text("Order").frame(
            minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
        }
        .font(.headline)
        ForEach($customphraseVM.customPhrases) { $customPhrase in
          HStack(alignment: .center) {
            Toggle(
              "",
              isOn: Binding(
                get: { customphraseVM.isEnabled[customPhrase.id] ?? true },
                set: {
                  customphraseVM.isEnabled[customPhrase.id] = $0
                }
              )
            ).frame(width: checkboxColumnWidth)
            TextField("Keyword", text: $customPhrase.keyword).frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
            TextField("Phrase", text: $customPhrase.phrase).frame(
              minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
            TextField("Order", value: $customPhrase.order, formatter: numberFormatter).frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
          }
        }
      }

      VStack {
        Button {
          reloadCustomPhrase()
        } label: {
          Text("Reload")
        }

        Button {
          openPanel.allowsMultipleSelection = true
          openPanel.canChooseDirectories = false
          openPanel.allowedContentTypes = [UTType.init(filenameExtension: "plist")!]
          openPanel.directoryURL = URL(
            fileURLWithPath: customPhraseSelectedDirectory
              ?? homeDir.appendingPathComponent("Desktop").localPath())
          openPanel.begin { response in
            if response == .OK {
              mkdirP(customphrasePath)
              for file in openPanel.urls {
                for (shortcut, phrase) in parseCustomPhraseXML(file) {
                  let newItem = CustomPhrase(keyword: shortcut, phrase: phrase, order: 1)
                  customphraseVM.isEnabled[newItem.id] = true
                  customphraseVM.customPhrases.append(newItem)
                }
              }
            }
            customPhraseSelectedDirectory = openPanel.directoryURL?.localPath()
          }
        } label: {
          Text("Import native custom phrases").tooltip(
            NSLocalizedString(
              "In IM menu → Edit Text Substitutions…, select all and drag them to desktop, then import the .plist file.",
              comment: ""))
        }

        Button {
          let newItem = CustomPhrase(keyword: "", phrase: "", order: 1)
          customphraseVM.isEnabled[newItem.id] = true
          customphraseVM.customPhrases.append(newItem)
          selectedRows = [newItem.id]
        } label: {
          Text("Add item")
        }

        Button {
          customphraseVM.customPhrases.removeAll {
            selectedRows.contains($0.id)
          }
          customphraseVM.isEnabled = customphraseVM.isEnabled.filter { id, _ in
            !selectedRows.contains(id)
          }
          selectedRows.removeAll()
        } label: {
          Text("Remove items")
        }.disabled(selectedRows.isEmpty)

        Button {
          mkdirP(customphrasePath)
          writeUTF8(
            customphrase,
            customPhrasesToString(customphraseVM) + "\n")
          reloadCustomPhrase()
        } label: {
          Text("Save")
        }.buttonStyle(.borderedProminent)

        Button {
          mkdirP(customphrasePath)
          if !customphrase.exists() {
            writeUTF8(customphrase, "")
          }
          openInEditor(customphrase.localPath())
        } label: {
          Text("Open in editor")
        }
      }
    }.padding()
      .frame(minWidth: 600, minHeight: 300)
  }
}
