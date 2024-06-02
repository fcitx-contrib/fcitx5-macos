import SwiftUI

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
      Text("Reset to default")
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
