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

private let binDir = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("fcitx5")
  .appendingPathComponent("bin")

func importDict(_ file: URL) -> Bool {
  do {
    try FileManager.default.copyItem(
      at: file, to: dictDir.appendingPathComponent(file.lastPathComponent))
    return true
  } catch {
    FCITX_ERROR(error.localizedDescription)
    return false
  }
}

func importTxtDict(_ file: URL) -> Bool {
  let path = file.localPath()
  FCITX_INFO("Importing \(path)")
  let converter = binDir.appendingPathComponent("libime_pinyindict").localPath()
  let name = file.deletingPathExtension().lastPathComponent
  return exec(
    converter,
    [path, dictDir.appendingPathComponent(name).appendingPathExtension("dict").localPath()])
}

func importScelDict(_ file: URL) -> Bool {
  let path = file.localPath()
  FCITX_INFO("Importing \(path)")
  let converter = binDir.appendingPathComponent("scel2org5").localPath()
  let name = "/tmp/\(file.deletingPathExtension().lastPathComponent).txt"
  if exec(converter, ["-o", name, path]) {
    return importTxtDict(URL(fileURLWithPath: name))
  }
  return false
}

struct Dict: Identifiable, Hashable {
  let id: String
}

class DictVM: ObservableObject {
  @Published private(set) var dicts: [Dict] = []

  func refreshDicts() {
    dicts = getFileNamesWithExtension(dictDir.localPath(), ".dict").map { Dict(id: $0) }
  }
}

struct DictManagerView: View {
  let openPanel = NSOpenPanel()
  @AppStorage("DictManagerSelectedDirectory") var dictManagerSelectedDirectory: String?
  @State private var selectedDicts = Set<String>()
  @ObservedObject private var dictVM = DictVM()

  func refreshDicts() -> some View {
    dictVM.refreshDicts()
    return self
  }

  private func reloadDicts() {
    _ = refreshDicts()
    Fcitx.setConfig("fcitx://config/addon/pinyin/dictmanager", "{}")
  }

  var body: some View {
    HStack {
      List(selection: $selectedDicts) {
        ForEach(dictVM.dicts) { dict in
          Text(dict.id)
        }
      }
      VStack {
        Button("Import dictionaries") {
          openPanel.allowsMultipleSelection = true
          openPanel.canChooseDirectories = false
          openPanel.allowedContentTypes = ["dict", "scel", "txt"].map {
            UTType.init(filenameExtension: $0)!
          }
          openPanel.directoryURL = URL(
            fileURLWithPath: dictManagerSelectedDirectory ?? FileManager.default
              .homeDirectoryForCurrentUser.localPath() + "/Downloads")
          openPanel.begin { response in
            if response == .OK {
              mkdirP(dictDir.localPath())
              for file in openPanel.urls {
                switch file.pathExtension {
                case "dict":
                  importDict(file)
                case "scel":
                  importScelDict(file)
                case "txt":
                  importTxtDict(file)
                default: break
                }
              }
            }
            reloadDicts()
            dictManagerSelectedDirectory = openPanel.directoryURL?.localPath()
          }
        }

        urlButton(
          NSLocalizedString("Sogou Cell Dictionary", comment: ""), "https://pinyin.sogou.com/dict/")

        Button("Remove dictionaries") {
          for dict in selectedDicts {
            removeFile(dictDir.appendingPathComponent(dict + ".dict"))
          }
          selectedDicts.removeAll()
          reloadDicts()
        }.disabled(selectedDicts.isEmpty)

        Button("Open dictionary directory") {
          mkdirP(dictDir.localPath())
          NSWorkspace.shared.open(dictDir)
        }
      }
    }.padding()
  }
}
