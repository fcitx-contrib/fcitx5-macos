import SwiftUI

let genericFamilies = [
  "cursive",
  "fangsong",
  "fantasy",
  "kai",
  "khmer-mul",
  // "math", // Not supported by Safari
  "monospace",
  "nastaliq",
  "sans-serif",
  "serif",
  "system-ui",
  "ui-monospace",
  "ui-rounded",
  "ui-sans-serif",
  "ui-serif",
]

struct FontOptionView: OptionView {
  let label: String
  @ObservedObject var model: FontOption
  @State private var selectorIsOpen = false
  @State var searchInput = ""
  @State var previewInput = NSLocalizedString("Preview", comment: "")

  // If initialize [], the sheet will list nothing on first open.
  @State var availableFontFamilies = NSFontManager.shared.availableFontFamilies
  var filteredFontFamilies: [String] {
    if searchInput.trimmingCharacters(in: .whitespaces).isEmpty {
      return availableFontFamilies
    } else {
      return availableFontFamilies.filter {
        $0.localizedCaseInsensitiveContains(searchInput)
          || localize($0).localizedCaseInsensitiveContains(searchInput)
      }
    }
  }
  @State private var selectedFontFamily: String?

  var body: some View {
    Button(action: openSelector) {
      if model.value.isEmpty {
        Text("Select font")
      } else {
        Text(localize(model.value))
      }
    }
    .sheet(isPresented: $selectorIsOpen) {
      VStack {
        TabView {
          VStack {
            TextField(NSLocalizedString("Search", comment: ""), text: $searchInput)
            TextField(NSLocalizedString("Preview", comment: ""), text: $previewInput)
            Text(previewInput).font(Font.custom(selectedFontFamily ?? model.value, size: 32)).frame(
              height: 64)
            List(selection: $selectedFontFamily) {
              ForEach(filteredFontFamilies, id: \.self) { family in
                HStack {
                  Text(localize(family)).font(Font.custom(family, size: 14))
                  Spacer()
                  Text(localize(family))
                }
              }
            }.contextMenu(forSelectionType: String.self) { items in
            } primaryAction: { items in
              // Double click
              select()
            }
          }.padding()
            .tabItem { Text("Font family") }

          VStack {
            List(selection: $selectedFontFamily) {
              ForEach(genericFamilies, id: \.self) { family in
                Text(family)
              }
            }.contextMenu(forSelectionType: String.self) { items in
            } primaryAction: { items in
              // Double click
              select()
            }
          }.padding()
            .tabItem { Text("Generic font families") }
        }

        HStack {
          Button {
            selectorIsOpen = false
          } label: {
            Text("Cancel")
          }
          Spacer()
          Button {
            select()
          } label: {
            Text("Select")
          }.buttonStyle(.borderedProminent)
            .disabled(selectedFontFamily == nil)
        }.padding([.leading, .trailing, .bottom])
      }
      .padding(.top)
      .frame(minWidth: 500, minHeight: 600)
    }
  }

  private func openSelector() {
    availableFontFamilies = NSFontManager.shared.availableFontFamilies
    selectorIsOpen = true
  }

  private func select() {
    if let selectedFontFamily = selectedFontFamily {
      model.value = selectedFontFamily
    }
    selectorIsOpen = false
  }

  private func localize(_ fontFamily: String) -> String {
    return NSFontManager.shared.localizedName(forFamily: fontFamily, face: nil)
  }
}
