import AlertToast
import Fcitx
import SwiftUI

private let globalQuickphrasePath =
  "/Library/Input Methods/Fcitx5.app/Contents/share/fcitx5/data/quickphrase.d"
private let globalQuickphraseDir = URL(fileURLWithPath: globalQuickphrasePath)
let localQuickphraseDir = localDir.appendingPathComponent("data/quickphrase.d")
let localQuickphrasePath = localQuickphraseDir.localPath()

class QuickPhraseVM: ObservableObject {
  @Published var selectedRows = Set<UUID>()
  @Published var current = "" {
    didSet {
      selectedRows.removeAll()
    }
  }
  @Published private(set) var userFiles: [String] = []
  @Published private(set) var files: [String] = []
  @Published var quickPhrases: [String: [QuickPhrase]] = [:]

  func refreshFiles() {
    quickPhrases = [:]
    userFiles = getFileNamesWithExtension(localQuickphrasePath, ".mb")
    for file in userFiles {
      quickPhrases[file] = stringToQuickPhrases(
        readUTF8(localQuickphraseDir.appendingPathComponent(file + ".mb")) ?? "")
    }
    files = userFiles
    for file in getFileNamesWithExtension(globalQuickphrasePath, ".mb") {
      if !userFiles.contains(file) {
        files.append(file)
        quickPhrases[file] = stringToQuickPhrases(
          readUTF8(globalQuickphraseDir.appendingPathComponent(file + ".mb")) ?? "")
      }
    }
    if files.isEmpty {
      current = ""
    } else if current.isEmpty || !files.contains(current) {
      current = files[0]
    }
  }
}

struct QuickPhrase: Identifiable {
  let id = UUID()
  var keyword: String
  var phrase: String
}

private func parseLine(_ s: String) -> QuickPhrase? {
  let regex = try! NSRegularExpression(pattern: "(\\S+)\\s+(\\S.*)", options: [])
  let matches = regex.matches(
    in: s, options: [], range: NSRange(location: 0, length: s.utf16.count))

  if let match = matches.first {
    let keyword = String(s[Range(match.range(at: 1), in: s)!])
    let phrase = String(s[Range(match.range(at: 2), in: s)!])
    return QuickPhrase(keyword: keyword, phrase: phrase)
  }
  return nil
}

private func stringToQuickPhrases(_ s: String) -> [QuickPhrase] {
  return s.split(separator: "\n").compactMap { line in
    parseLine(String(line))
  }
}

private func quickPhrasesToString(_ quickPhrases: [QuickPhrase]) -> String {
  return quickPhrases.map { quickPhrase in
    "\(quickPhrase.keyword) \(quickPhrase.phrase)"
  }.joined(separator: "\n")
}

struct QuickPhraseView: View {
  @Environment(\.presentationMode) var presentationMode

  @State private var showNewFile = false
  @State private var newFileName = ""
  @ObservedObject private var quickphraseVM = QuickPhraseVM()
  @State private var showReloaded = false
  @State private var showCreateFailed = false
  @State private var showRemoveFailed = false
  @State private var showSaved = false
  @State private var showSavedFailure = false

  func refreshFiles() -> some View {
    quickphraseVM.refreshFiles()
    return self
  }

  func reloadQuickPhrase() {
    _ = refreshFiles()
    Fcitx.setConfig("fcitx://config/addon/quickphrase/editor", "{}")
  }

  var body: some View {
    HStack {
      VStack {
        Picker("", selection: $quickphraseVM.current) {
          ForEach(quickphraseVM.files, id: \.self) { file in
            Text(file)
          }
        }
        List(selection: $quickphraseVM.selectedRows) {
          HStack {
            Text("Keyword").frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
            Text("Phrase").frame(
              minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
          }
          .font(.headline)

          ForEach(
            Binding(
              get: { quickphraseVM.quickPhrases[quickphraseVM.current] ?? [] },
              set: { quickphraseVM.quickPhrases[quickphraseVM.current] = $0 }
            )
          ) { $quickPhrase in
            HStack {
              TextField("Keyword", text: $quickPhrase.keyword).frame(
                minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
              TextField("Phrase", text: $quickPhrase.phrase).frame(
                minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      VStack {
        Button {
          reloadQuickPhrase()
          showReloaded = true
        } label: {
          Text("Reload")
        }

        Button {
          showNewFile = true
        } label: {
          Text("New file")
        }

        Button {
          let newItem = QuickPhrase(keyword: "", phrase: "")
          quickphraseVM.quickPhrases[quickphraseVM.current]?.append(newItem)
          quickphraseVM.selectedRows = [newItem.id]
        } label: {
          Text("Add item")
        }

        Button {
          quickphraseVM.quickPhrases[quickphraseVM.current]?.removeAll {
            quickphraseVM.selectedRows.contains($0.id)
          }
          quickphraseVM.selectedRows.removeAll()
        } label: {
          Text("Remove items")
        }.disabled(quickphraseVM.selectedRows.isEmpty)

        Button {
          mkdirP(localQuickphrasePath)
          if writeUTF8(
            localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
            quickPhrasesToString(quickphraseVM.quickPhrases[quickphraseVM.current] ?? []) + "\n")
          {
            showSaved = true
            reloadQuickPhrase()
          } else {
            showSavedFailure = true
          }
        } label: {
          Text("Save")
        }.disabled(quickphraseVM.current.isEmpty)
          .buttonStyle(.borderedProminent)

        Button {
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          var ret: Bool
          if quickphraseVM.userFiles.contains(quickphraseVM.current) {
            ret = removeFile(localURL)
          } else {
            // Create an empty file to disable the global one
            mkdirP(localQuickphrasePath)
            ret = writeUTF8(localURL, "")
          }
          if ret {
            reloadQuickPhrase()
          } else {
            showRemoveFailed = true
          }
        } label: {
          Text("Remove")
        }.disabled(quickphraseVM.current.isEmpty)

        Button {
          mkdirP(localQuickphrasePath)
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          if !localURL.exists() {
            if !copyFile(
              globalQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
              localURL)
            {
              showCreateFailed = true
              return
            }
          }
          openInEditor(url: localURL)
        } label: {
          Text("Open in editor")
        }.disabled(quickphraseVM.current.isEmpty)

        Button {
          mkdirP(localQuickphrasePath)
          NSWorkspace.shared.open(localQuickphraseDir)
        } label: {
          Text("Open directory")
        }

        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Close")
        }
      }
      .sheet(isPresented: $showNewFile) {
        VStack {
          HStack {
            Text("Name")
            TextField("", text: $newFileName)
          }
          HStack {
            Button {
              showNewFile = false
            } label: {
              Text("Cancel")
            }
            Button {
              let localURL = localQuickphraseDir.appendingPathComponent(newFileName + ".mb")
              if !writeUTF8(localURL, "") {
                showCreateFailed = true
                return
              }
              showNewFile = false
              _ = refreshFiles()
              quickphraseVM.current = newFileName
              newFileName = ""
            } label: {
              Text("Create")
            }.buttonStyle(.borderedProminent)
              .disabled(newFileName.isEmpty || quickphraseVM.userFiles.contains(newFileName))
          }
        }.padding()
          .frame(minWidth: 200)
      }
    }.padding()
      .frame(minWidth: 500, minHeight: 300)
      .toast(isPresenting: $showReloaded) {
        AlertToast(
          displayMode: .hud, type: .complete(Color.green),
          title: NSLocalizedString("Reloaded", comment: ""))
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
      .toast(isPresenting: $showRemoveFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to remove", comment: ""))
      }
  }
}
