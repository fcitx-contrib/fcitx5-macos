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

private let dictPath = dictDir.localPath()

private let binDir = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("fcitx5")
  .appendingPathComponent("bin")

func importDict(_ file: URL) -> Bool {
  return copyFile(file, dictDir.appendingPathComponent(file.lastPathComponent))
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
  @Published var isEnabled: [String: Bool] = [:]
  @Published private(set) var dicts: [Dict] = []

  func refreshDicts() {
    let enabled = getFileNamesWithExtension(dictPath, ".dict")
    let disabled = getFileNamesWithExtension(dictPath, ".dict.disable")
    dicts = (enabled + disabled).sorted().map { Dict(id: $0) }
    isEnabled = [:]
    for d in enabled {
      isEnabled[d] = true
    }
    for d in disabled {
      isEnabled[d] = false
    }
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
          // Separate so clicking text doesn't toggle checkbox.
          HStack(alignment: .center) {
            Toggle(
              "",
              isOn: Binding(
                get: { dictVM.isEnabled[dict.id]! },
                set: {
                  dictVM.isEnabled[dict.id] = $0
                  let enabledPath = dictDir.appendingPathComponent(dict.id + ".dict")
                  let disabledPath = dictDir.appendingPathComponent(dict.id + ".dict.disable")
                  if $0 {
                    moveFile(disabledPath, enabledPath)
                  } else {
                    moveFile(enabledPath, disabledPath)
                  }
                  reloadDicts()
                }
              ))
            Text(dict.id)
          }
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
              mkdirP(dictPath)
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
          mkdirP(dictPath)
          NSWorkspace.shared.open(dictDir)
        }
      }
    }.padding()
  }
}
