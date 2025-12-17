import SwiftUI

struct EnumOptionView: OptionView {
  let label: String
  @ObservedObject var model: EnumOption
  @State private var showHelp = false

  private func getCount() -> Int {
    // Hack: on macOS < 26 disable Liquid Glass of Background/Blur in webpanel.
    if model.enumStrings.prefix(4) == ["None", "System", "Blur", "Liquid Glass"] {
      if osVersion.majorVersion >= 26 {
        return 4
      }
      return 3
    }
    return model.enumStrings.count
  }

  private func isThemeWithLiquidGlass() -> Bool {
    if model.enumStrings.prefix(3) == ["System", "Light", "Dark"] && osVersion.majorVersion >= 26 {
      let blur = ProcessInfo.processInfo.environment["BLUR"]
      return blur == "1" || blur == "3"
    }
    return false
  }

  var body: some View {
    if isThemeWithLiquidGlass() {
      HStack {
        Text("Follow App background (Liquid Glass)")
        Button {
          showHelp = true
        } label: {
          Text("?")
        }.frame(width: 20, height: 20)
          .clipShape(Circle())
          .sheet(isPresented: $showHelp) {
            VStack {
              Text(
                "When Liquid Glass is enabled, theme follows App background, which is the same behavior with built-in input methods.\nTo set fixed light/dark theme, please change Background → Blur to \"None\" or \"Blur\"."
              )
              Button {
                showHelp = false
              } label: {
                Text("OK")
              }.buttonStyle(.borderedProminent)
            }.padding()
          }
      }
    } else {
      Picker("", selection: $model.value) {
        ForEach(0..<getCount(), id: \.self) { i in
          Text(model.enumStringsI18n[i]).tag(model.enumStrings[i])
        }
      }
    }
  }
}
