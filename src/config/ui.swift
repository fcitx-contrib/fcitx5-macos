import SwiftUI

let sectionHeaderSize: CGFloat = 16
let gapSize: CGFloat = 10
let checkboxColumnWidth: CGFloat = 20

extension View {
  func tooltip(_ text: String) -> some View {
    HStack {
      self
      Image(systemName: "questionmark.circle.fill").help(text)
    }
  }
}
