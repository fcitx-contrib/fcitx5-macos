import Fcitx
import SwiftUI

private let customphraseDir = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent(".local")
  .appendingPathComponent("share")
  .appendingPathComponent("fcitx5")
  .appendingPathComponent("pinyin")

private let customphrase = customphraseDir.appendingPathComponent("customphrase")

struct CustomPhrase: Identifiable {
  let id = UUID()
  var keyword: String
  var phrase: String
  var order: Int
  var enabled: Bool
}

private func parseLine(_ s: String) -> CustomPhrase? {
  let regex = try! NSRegularExpression(pattern: "(\\S+),(-?\\d+)=(.+)", options: [])
  let matches = regex.matches(
    in: s, options: [], range: NSRange(location: 0, length: s.utf16.count))

  if let match = matches.first {
    let keyword = String(s[Range(match.range(at: 1), in: s)!])
    let order = Int(String(s[Range(match.range(at: 2), in: s)!])) ?? 0
    let phrase = String(s[Range(match.range(at: 3), in: s)!])
    return CustomPhrase(keyword: keyword, phrase: phrase, order: abs(order), enabled: order > 0)
  }
  return nil
}

private func stringToCustomPhrases(_ s: String) -> [CustomPhrase] {
  return s.split(separator: "\n").compactMap { line in
    parseLine(String(line))
  }
}

class CustomPhraseVM: ObservableObject {
  @Published var customPhrases: [CustomPhrase] = []

  func refreshItems() {
    customPhrases = stringToCustomPhrases(readUTF8(customphrase) ?? "")
  }
}

struct CustomPhraseView: View {
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
      }
    }.padding()
      .frame(minWidth: 600, minHeight: 300)
  }
}
