import Fcitx
import SwiftUI

struct ExportThemeView: View {
  @Environment(\.presentationMode) var presentationMode
  @State private var themeName = ""

  var body: some View {
    VStack {
      TextField(NSLocalizedString("Theme name", comment: ""), text: $themeName)
      HStack {
        Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Cancel")
        }
        Button {
          Fcitx.setConfig(
            "fcitx://config/addon/webpanel/exportcurrenttheme", "\"\(quote(themeName))\"")
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("OK")
        }.disabled(themeName.isEmpty)
          .buttonStyle(.borderedProminent)
      }
    }.padding()
      .frame(minWidth: 200)
  }
}
