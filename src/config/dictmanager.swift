import Fcitx
import Logging
import SwiftUI
import UniformTypeIdentifiers

private let dictDir = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent(".local")
  .appendingPathComponent("share")
  .appendingPathComponent("fcitx5")
  .appendingPathComponent("pinyin")
  .appendingPathComponent("dictionaries")

struct Dict: Identifiable, Hashable {
  let id: String
}

class DictVM: ObservableObject {
  @Published private(set) var dicts: [Dict] = []

  func refreshDicts() {
    dicts = getFileNamesWithExtension(dictDir.path(), ".dict").map { Dict(id: $0) }
  }
}

struct DictManagerView: View {
  @AppStorage("DictManagerSelectedDirectory") var dictManagerSelectedDirectory: String?
  @ObservedObject private var dictVM = DictVM()

  func refreshDicts() -> some View {
    dictVM.refreshDicts()
    return self
  }

  private func reloadDicts() {
    refreshDicts()
    Fcitx.setConfig("fcitx://config/addon/pinyin/dictmanager", "{}")
  }

  var body: some View {
    HStack {
      List {
        ForEach(dictVM.dicts) { dict in
          Text(dict.id)
        }
      }
      VStack {
        Button("Import dictionary") {
          let openPanel = NSOpenPanel()
          openPanel.allowsMultipleSelection = true
          openPanel.canChooseDirectories = false
          openPanel.allowedContentTypes = ["dict", "scel", "txt"].map {
            UTType.init(filenameExtension: $0)!
          }
          openPanel.directoryURL = URL(
            fileURLWithPath: dictManagerSelectedDirectory ?? FileManager.default
              .homeDirectoryForCurrentUser.path + "/Downloads")
          openPanel.begin { response in
            if response == .OK {
              mkdirP(dictDir.path())

              do {
                for file in openPanel.urls {
                  switch file.pathExtension {
                  case "dict":
                    try FileManager.default.copyItem(
                      at: file, to: dictDir.appendingPathComponent(file.lastPathComponent))
                  case "scel":
                    FCITX_ERROR("scel")
                  case "txt":
                    FCITX_ERROR("txt")
                  default: break
                  }
                }
              } catch {
                FCITX_ERROR(error.localizedDescription)
              }
            }
            reloadDicts()
            dictManagerSelectedDirectory = openPanel.directoryURL?.path
          }
        }
        urlButton(
          NSLocalizedString("Sogou Cell Dictionary", comment: ""), "https://pinyin.sogou.com/dict/")
        Button("Open dictionary directory") {
          mkdirP(dictDir.path())
          NSWorkspace.shared.open(dictDir)
        }
      }
    }.padding()
  }
}
