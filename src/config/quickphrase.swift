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

private let minKeywordColumnWidth: CGFloat = 100
private let minPhraseColumnWidth: CGFloat = 200

class QuickPhraseVM: ObservableObject {
  @Published var current = "" {
    didSet {
      guard !current.isEmpty else { return }
      var content: String? = nil
      let name = current + ".mb"
      let localURL = localQuickphraseDir.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: localURL.localPath()) {
        content = readUTF8(localURL)
      } else {
        content = readUTF8(globalQuickphraseDir.appendingPathComponent(name))
      }
      if content != nil {
        quickPhrases = stringToQuickPhrases(content!)
      }
    }
  }
  @Published private(set) var files: [String] = []
  @Published var quickPhrases: [QuickPhrase] = []

  func refreshFiles() {
    files = getFileNamesWithExtension(localQuickphrasePath, ".mb")
    for file in getFileNamesWithExtension(globalQuickphrasePath, ".mb") {
      if !files.contains(file) {
        files.append(file)
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
  @State private var selectedRows = Set<UUID>()
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
        List(selection: $selectedRows) {
          HStack {
            Text("Keyword").frame(
              minWidth: minKeywordColumnWidth, maxWidth: .infinity, alignment: .leading)
            Text("Phrase").frame(
              minWidth: minPhraseColumnWidth, maxWidth: .infinity, alignment: .leading)
          }
          .font(.headline)

          ForEach($quickphraseVM.quickPhrases) { $quickPhrase in
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
          mkdirP(localQuickphrasePath)
          writeUTF8(
            localQuickphraseDir.appendingPathComponent(quickphraseVM.current + ".mb"),
            quickPhrasesToString(quickphraseVM.quickPhrases) + "\n")
          reloadQuickPhrase()
        } label: {
          Text("Save")
        }.disabled(quickphraseVM.current.isEmpty)
        Button {
          mkdirP(localQuickphrasePath)
          NSWorkspace.shared.open(localQuickphraseDir)
        } label: {
          Text("Open quick phrase directory")
        }
      }
    }.padding()
      .frame(minWidth: 500, minHeight: 300)
  }
}
