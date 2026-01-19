import Fcitx
import Logging
import SwiftUI

class ImportTableVM: ObservableObject {
  // Record IMs and auto add new ones.
  @Published private(set) var ims = [String]()
  var onError: (String) -> Void = { _ in }
  var finalize: () -> Void = {}

  func setHandler(onError: @escaping (String) -> Void, finalize: @escaping () -> Void) {
    self.onError = onError
    self.finalize = finalize
  }

  func load() {
    ims = getFileNamesWithExtension(imLocalDir.localPath(), ".conf")
  }
}

private func convertTxt() -> [String] {
  let converter = libraryDir.appendingPathComponent("bin/libime_tabledict").localPath()
  let tables = getFileNamesWithExtension(tableLocalDir.localPath(), ".txt")
  return tables.filter({ table in
    let src = tableLocalDir.appendingPathComponent("\(table).txt")
    return
      !(exec(
        converter,
        [src.localPath(), tableLocalDir.appendingPathComponent("\(table).dict").localPath()])
      && removeFile(src))
  })
}

struct ImportTableView: View {
  @Environment(\.presentationMode) var presentationMode

  @ObservedObject private var importTableVM = ImportTableVM()

  func load(onError: @escaping (String) -> Void, finalize: @escaping () -> Void) -> some View {
    mkdirP(imLocalDir.localPath())
    mkdirP(tableLocalDir.localPath())
    importTableVM.setHandler(onError: onError, finalize: finalize)
    importTableVM.load()
    return self
  }

  var body: some View {
    VStack(spacing: gapSize) {
      Button {
        NSWorkspace.shared.open(imLocalDir)
      } label: {
        Text("Copy \\*.conf to this directory")
      }
      Button {
        NSWorkspace.shared.open(tableLocalDir)
      } label: {
        Text("Copy \\*.dict/\\*.txt to this directory")
      }

      HStack {
        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Cancel")
        }

        Button {
          let existingIMs = Set(importTableVM.ims)
          let failures = convertTxt()
          importTableVM.load()
          let newIMs = importTableVM.ims.filter({ im in !existingIMs.contains(im) })
          Fcitx.reload()
          if Fcitx.imGroupCount() == 1 {
            for im in newIMs {
              Fcitx.imAddToCurrentGroup(im)
            }
          }
          presentationMode.wrappedValue.dismiss()
          if !failures.isEmpty {
            let msg = String(
              format: NSLocalizedString("Failed to convert txt table(s): %@", comment: ""),
              failures.joined(separator: ", "))
            importTableVM.onError(msg)
          }
          importTableVM.finalize()
        } label: {
          Text("Reload")
        }.buttonStyle(.borderedProminent)
      }
    }.padding()
  }
}
