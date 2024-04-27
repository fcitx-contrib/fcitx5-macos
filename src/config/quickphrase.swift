import SwiftUI

private let globalQuickphrasePath =
  "/Library/Input Methods/Fcitx5.app/Contents/share/fcitx5/data/quickphrase.d"
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
  @Published var current = ""
  @Published private(set) var files: [String] = []

  func refreshFiles() {
    files = getFileNamesWithExtension(globalQuickphrasePath, ".mb")
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

struct QuickPhraseView: View {
  @State private var quickPhrases = [
    QuickPhrase(keyword: "Hello", phrase: "Hi there"),
    QuickPhrase(keyword: "Goodbye", phrase: "See you later"),
  ]
  @State private var selectedRows = Set<UUID>()
  @ObservedObject private var quickphraseVM = QuickPhraseVM()

  func refreshFiles() -> some View {
    quickphraseVM.refreshFiles()
    return self
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

          ForEach($quickPhrases) { $quickPhrase in
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
          NSWorkspace.shared.open(localQuickphraseDir)
        } label: {
          Text("Open quick phrase directory")
        }
      }
    }.padding()
      .frame(minWidth: 500, minHeight: 300)
  }
}
