import SwiftUI
import UniformTypeIdentifiers

let sectionHeaderSize: CGFloat = 16
let gapSize: CGFloat = 10
let checkboxColumnWidth: CGFloat = 20
let minKeywordColumnWidth: CGFloat = 80
let minPhraseColumnWidth: CGFloat = 160
let configWindowWidth: CGFloat = 800
let configWindowHeight: CGFloat = 600

let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]

extension View {
  func tooltip(_ text: String) -> some View {
    HStack {
      self
      Image(systemName: "questionmark.circle.fill").help(text)
    }
  }
}

func footer(reset: @escaping () -> Void, apply: @escaping () -> Void, close: @escaping () -> Void)
  -> some View
{
  return HStack {
    Button {
      reset()
    } label: {
      Text("Reset to default").tooltip(
        NSLocalizedString(
          "Reset current page. To reset a single item/group, right click on its label.", comment: ""
        ))
    }
    Button {
      close()
    } label: {
      Text("Cancel")
    }
    Spacer()
    Button {
      apply()
    } label: {
      Text("Apply")
    }
    Button {
      apply()
      close()
    } label: {
      Text("OK")
    }
    .buttonStyle(.borderedProminent)
  }.padding()
}

func urlButton(_ text: String, _ link: String) -> some View {
  Button(
    action: {
      if let url = URL(string: link) {
        NSWorkspace.shared.open(url)
      }
    },
    label: {
      Text(text)
        .foregroundColor(.blue)
    }
  ).buttonStyle(PlainButtonStyle())
    .focusable(false)
}

struct SelectFileButton<Label>: View where Label: View {
  let directory: URL
  let allowedContentTypes: [UTType]
  let onFinish: (String) -> Void
  let label: () -> Label
  let model: Binding<String>

  @State private var openPanel = NSOpenPanel()
  @State private var showDuplicate = false
  @State private var src: URL? = nil

  var body: some View {
    HStack {
      Button(
        action: {
          mkdirP(directory.localPath())
          // Only consider the first file, but allow multiple deletion.
          openPanel.allowsMultipleSelection = true
          openPanel.canChooseDirectories = false
          openPanel.allowedContentTypes = allowedContentTypes
          openPanel.directoryURL = directory
          openPanel.begin { response in
            if response == .OK {
              guard let file = openPanel.urls.first else {
                return
              }
              var fileName = file.lastPathComponent
              if !directory.contains(file) {
                let dst = directory.appendingPathComponent(fileName)
                if dst.exists() {
                  src = file
                  showDuplicate = true
                  return
                }
                if !copyFile(file, dst) {
                  return
                }
              } else {
                // Need to consider subdirectory of www/img.
                fileName = String(file.localPath().dropFirst(directory.localPath().count))
              }
              onFinish(fileName)
            }
          }
        },
        label: label
      ).sheet(isPresented: $showDuplicate) {
        VStack {
          Text("\(src!.lastPathComponent) already exists. Replace?")
          HStack {
            Button {
              showDuplicate = false
            } label: {
              Text("Cancel")
            }
            Button {
              showDuplicate = false
              guard let src = src else { return }
              let fileName = src.lastPathComponent
              let dst = directory.appendingPathComponent(fileName)
              _ = removeFile(dst)
              if copyFile(src, dst) {
                onFinish(fileName)
              }
            } label: {
              Text("OK")
            }.buttonStyle(.borderedProminent)
          }
        }.padding()
      }
      if !model.wrappedValue.isEmpty {
        Button {
          model.wrappedValue = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
        }.buttonStyle(BorderlessButtonStyle())
      }
    }
  }
}
