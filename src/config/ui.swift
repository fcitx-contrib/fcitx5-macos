import SwiftUI

let sectionHeaderSize: CGFloat = 16
let gapSize: CGFloat = 10

extension View {
  func tooltip(_ text: String) -> some View {
    HStack {
      self
      Image(systemName: "questionmark.circle.fill").help(text)
    }
  }
}
