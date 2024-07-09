import AlertToast
import Fcitx
import SwiftUI
import UniformTypeIdentifiers

let pinyinPath = pinyinLocalDir.localPath()

let customphrase = pinyinLocalDir.appendingPathComponent("customphrase")
let nativeCustomPhrase = cacheDir.appendingPathComponent("customphrase.plist")

struct CustomPhrase: Identifiable, Hashable {
  var id: Int {
    var hasher = Hasher()
    hasher.combine(keyword)
    hasher.combine(phrase)
    return hasher.finalize()
  }
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
  @Published var isEnabled: [Int: Bool] = [:]

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
  @Environment(\.presentationMode) var presentationMode

  @State private var selectedRows = Set<Int>()
  @ObservedObject private var customphraseVM = CustomPhraseVM()
  @State private var showReloaded = false
  @State private var importedPhrases = 0
  @State private var showImportedPhrases = false
  @State private var showSaved = false
  // Test: cd ~/.local/share/fcitx5; sudo chown root pinyin
  @State private var showSavedFailure = false
  @State private var showCreateFailed = false

  func refreshItems() -> some View {
    selectedRows = []
    customphraseVM.refreshItems()
    return self
  }

  func reloadCustomPhrase() {
    _ = refreshItems()
    Fcitx.setConfig("fcitx://config/addon/pinyin/customphrase", "{}")
  }

  private func save() -> Bool {
    mkdirP(pinyinPath)
    if writeUTF8(customphrase, customPhrasesToString(customphraseVM) + "\n") {
      reloadCustomPhrase()
      return true
    }
    return false
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
          showReloaded = true
        } label: {
          Text("Reload")
        }

        Button {
          mkdirP(cacheDir.localPath())
          if exec(
            "/bin/zsh",
            ["-c", "/usr/bin/defaults export -g - > \(quote(nativeCustomPhrase.localPath()))"])
          {
            let phrases = Set(customphraseVM.customPhrases)
            importedPhrases = 0
            for (shortcut, phrase) in parseCustomPhraseXML(nativeCustomPhrase) {
              let newItem = CustomPhrase(keyword: shortcut, phrase: phrase, order: 1)
              if !phrases.contains(newItem) {
                customphraseVM.isEnabled[newItem.id] = true
                customphraseVM.customPhrases.append(newItem)
                importedPhrases += 1
              }
            }
            if save() {
              showImportedPhrases = true
              _ = removeFile(nativeCustomPhrase)
            } else {
              showSavedFailure = true
            }
          }
        } label: {
          Text("Import native custom phrases")
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
          if save() {
            showSaved = true
          } else {
            showSavedFailure = true
          }
        } label: {
          Text("Save")
        }.buttonStyle(.borderedProminent)

        Button {
          mkdirP(pinyinPath)
          if !customphrase.exists() {
            if !writeUTF8(customphrase, "") {
              showCreateFailed = true
              return
            }
          }
          openInEditor(url: customphrase)
        } label: {
          Text("Open in editor")
        }

        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Close")
        }
      }
    }.padding()
      .frame(minWidth: 600, minHeight: 300)
      .toast(isPresenting: $showReloaded) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Reloaded", comment: ""))
      }
      .toast(isPresenting: $showImportedPhrases) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: importedPhrases == 0
            ? NSLocalizedString("All phrases are imported", comment: "")
            : String(
              format: NSLocalizedString("Imported %@ phrase(s)", comment: ""),
              String(importedPhrases)))
      }
      .toast(isPresenting: $showSaved) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Saved", comment: ""))
      }
      .toast(isPresenting: $showSavedFailure) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to save", comment: ""))
      }
      .toast(isPresenting: $showCreateFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to create", comment: ""))
      }
  }
}
