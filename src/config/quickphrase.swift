import Fcitx
import SwiftUI

private let globalQuickphrasePath =
  "/Library/Input Methods/Fcitx5.app/Contents/share/fcitx5/data/quickphrase.d"
private let globalQuickphraseDir = URL(fileURLWithPath: globalQuickphrasePath)
private let localQuickphraseDir = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent(".local")
  .appendingPathComponent("share")
  .appendingPathComponent("fcitx5")
  .appendingPathComponent("data")
  .appendingPathComponent("quickphrase.d")
private let localQuickphrasePath = localQuickphraseDir.localPath()

let minKeywordColumnWidth: CGFloat = 100
let minPhraseColumnWidth: CGFloat = 200

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
  @State private var showNewFile = false
  @State private var newFileName = ""
  @ObservedObject private var quickphraseVM = QuickPhraseVM()

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
          writeUTF8(
            localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
            quickPhrasesToString(quickphraseVM.quickPhrases[quickphraseVM.current] ?? []) + "\n")
          reloadQuickPhrase()
        } label: {
          Text("Save")
        }.disabled(quickphraseVM.current.isEmpty)
          .buttonStyle(.borderedProminent)

        Button {
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          if quickphraseVM.userFiles.contains(quickphraseVM.current) {
            removeFile(localURL)
          } else {
            // Create an empty file to disable the global one
            mkdirP(localQuickphrasePath)
            writeUTF8(localURL, "")
          }
          reloadQuickPhrase()
        } label: {
          Text("Remove")
        }.disabled(quickphraseVM.current.isEmpty)

        Button {
          let localURL = localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb")
          let path = localURL.localPath()
          if !FileManager.default.fileExists(atPath: path) {
            copyFile(
              globalQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
              localURL)
          }
          let apps = ["VSCodium", "Visual Studio Code"]
          for app in apps {
            let appURL = URL(fileURLWithPath: "/Applications/\(app).app")
            if FileManager.default.fileExists(atPath: appURL.localPath()) {
              NSWorkspace.shared.openFile(path, withApplication: app)
              return
            }
          }
          NSWorkspace.shared.openFile(path, withApplication: "TextEdit")
        } label: {
          Text("Open in editor")
        }.disabled(quickphraseVM.current.isEmpty)

        Button {
          mkdirP(localQuickphrasePath)
          NSWorkspace.shared.open(localQuickphraseDir)
        } label: {
          Text("Open directory")
        }
      }
      .sheet(isPresented: $showNewFile) {
        VStack {
          HStack {
            Text("Name")
            TextField("", text: $newFileName)
          }
          Button {
            if !newFileName.isEmpty && !quickphraseVM.userFiles.contains(newFileName) {
              let localURL = localQuickphraseDir.appendingPathComponent(newFileName + ".mb")
              writeUTF8(localURL, "")
              showNewFile = false
              refreshFiles()
              quickphraseVM.current = newFileName
              newFileName = ""
            }
          } label: {
            Text("Create")
          }.buttonStyle(.borderedProminent)
        }.padding()
          .frame(minWidth: 200)
      }
    }.padding()
      .frame(minWidth: 500, minHeight: 300)
  }
}
