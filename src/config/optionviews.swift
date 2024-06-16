import Fcitx
import Logging
import SwiftUI
import SwiftyJSON

protocol OptionView: View {
  var label: String { get }
  var overrideLabel: String? { get }
}

struct BooleanOptionView: OptionView {
  let label: String
  var overrideLabel: String? {
    return label
  }
  @ObservedObject var model: BooleanOption
  var body: some View {
    Toggle("", isOn: $model.value)
      .toggleStyle(.switch)
      .frame(alignment: .trailing)
  }
}

struct KeyOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: KeyOption
  @State private var showRecorder = false
  @State private var recordedShortcut = ""
  @State private var recordedKey = ""
  @State private var recordedModifiers = NSEvent.ModifierFlags()
  @State private var recordedCode: UInt16 = 0

  var body: some View {
    Button {
      showRecorder = true
    } label: {
      Text(model.value.isEmpty ? "●REC" : fcitxStringToMacShortcut(model.value)).frame(
        minWidth: 100)
    }.sheet(isPresented: $showRecorder) {
      VStack {
        Text(recordedShortcut)
          .background(
            RecordingOverlay(
              recordedShortcut: $recordedShortcut, recordedKey: $recordedKey,
              recordedModifiers: $recordedModifiers, recordedCode: $recordedCode)
          )
          .frame(minWidth: 200, minHeight: 50)
        HStack {
          Button {
            showRecorder = false
          } label: {
            Text("Cancel")
          }
          Button {
            model.value = macKeyToFcitxString(recordedKey, recordedModifiers, recordedCode)
            showRecorder = false
          } label: {
            Text("OK")
          }.buttonStyle(.borderedProminent)
        }
      }.padding()
    }.help(model.value.isEmpty ? NSLocalizedString("Click to record", comment: "") : model.value)
  }
}

struct StringOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: StringOption
  var body: some View {
    TextField(label, text: $model.value)
  }
}

let numberFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.allowsFloats = false
  formatter.usesGroupingSeparator = false
  return formatter
}()

struct IntegerOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: IntegerOption
  @FocusState private var isFocused: Bool

  var body: some View {
    ZStack(alignment: .trailing) {
      TextField(label, value: $model.value, formatter: numberFormatter)
        .focused($isFocused)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onChange(of: isFocused) { newValue in
          if !newValue {  // lose focus
            validate()
          }
        }
        .padding(.trailing, 60)
      HStack(spacing: 0) {
        Button {
          model.value -= 1
          validate()
        } label: {
          Image(systemName: "minus")
        }
        Button {
          model.value += 1
          validate()
        } label: {
          Image(systemName: "plus")
        }
      }
    }
  }

  func validate() {
    if let max = model.max,
      model.value > max
    {
      model.value = max
    } else if let min = model.min,
      model.value < min
    {
      model.value = min
    }
  }
}

struct ColorOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: ColorOption
  var body: some View {
    HStack {
      ColorPicker("", selection: $model.rgb, supportsOpacity: true)
      Text("Alpha (0-255)")
      TextField("", value: $model.alpha, formatter: numberFormatter).onChange(of: model.alpha) {
        newValue in
        if newValue > 255 {
          model.alpha = 255
        } else if newValue < 0 {
          model.alpha = 0
        }
      }
    }
  }
}

class ExternalConfigViewModel: ObservableObject {
  @Published var hasConfig = false
  @Published var hasError = false
  @Published var externalConfig: Config? {
    didSet {
      hasConfig = (externalConfig != nil)
    }
  }
  @Published var errorMsg: String? {
    didSet {
      hasError = (errorMsg != nil)
    }
  }

  func showConfig(_ uri: String) {
    externalConfig = nil
    errorMsg = nil
    do {
      externalConfig = try getConfig(uri: uri)
    } catch {
      FCITX_ERROR("When fetching external config: \(error)")
      errorMsg =
        NSLocalizedString("Cannot show external config: ", comment: "")
        + ": \(error.localizedDescription)"
    }
  }

  func saveExternalConfig(_ uri: String) {
    if !uri.hasPrefix("fcitx://config") { return }
    guard let config = externalConfig else { return }
    Fcitx.setConfig(uri, config.encodeValue())
  }
}

struct ExternalOptionView: OptionView {
  let label: String
  let model: ExternalOption
  let overrideLabel: String? = ""

  @StateObject private var viewModel = ExternalConfigViewModel()
  @State private var showCustomPhrase = false
  @State private var showDictManager = false
  @State private var showQuickPhrase = false

  var body: some View {
    Button(label) {
      switch model.option {
      case "UserFontDir":
        let fontDir = homeDir.appendingPathComponent("Library/Fonts")
        NSWorkspace.shared.open(fontDir)
      case "SystemFontDir":
        let fontDir = URL(fileURLWithPath: "/Library/Fonts")
        NSWorkspace.shared.open(fontDir)
      case "UserDataDir":
        mkdirP(rimeLocalDir.localPath())
        NSWorkspace.shared.open(rimeLocalDir)
      case "CustomPhrase":
        showCustomPhrase = true
      case "DictManager":
        showDictManager = true
      case "QuickPhrase":
        showQuickPhrase = true
      default:
        viewModel.showConfig(model.external)
      }
    }
    .sheet(isPresented: $showCustomPhrase) {
      CustomPhraseView().refreshItems()
    }
    .sheet(isPresented: $showDictManager) {
      DictManagerView().refreshDicts()
    }
    .sheet(isPresented: $showQuickPhrase) {
      QuickPhraseView().refreshFiles()
    }
    .sheet(isPresented: $viewModel.hasConfig) {
      VStack {
        ScrollView([.vertical]) {
          buildView(config: viewModel.externalConfig!).padding([.leading, .trailing])
        }.padding([.top])
        footer(
          reset: {
            viewModel.externalConfig?.resetToDefault()
          },
          apply: {
            viewModel.saveExternalConfig(model.external)
          },
          close: {
            viewModel.externalConfig = nil
          })
      }
      .frame(minWidth: 400)
    }
    .alert(
      Text("Error"),
      isPresented: $viewModel.hasError,
      presenting: ()
    ) { _ in
      Button {
        viewModel.errorMsg = nil
      } label: {
        Text("OK")
      }
      .buttonStyle(.borderedProminent)
    } message: { _ in
      Text(viewModel.errorMsg!)
    }
  }
}

struct EnumOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: EnumOption
  var body: some View {
    Picker("", selection: $model.value) {
      ForEach(0..<model.enumStrings.count, id: \.self) { i in
        Text(model.enumStringsI18n[i]).tag(model.enumStrings[i])
      }
    }
  }
}

struct ListOptionView<T: Option & EmptyConstructible>: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: ListOption<T>

  var body: some View {
    VStack {
      ForEach(model.value) { element in
        HStack {
          Spacer()
          AnyView(buildViewImpl(label: "", option: element.value))

          let index = findElementIndex(element)
          Button(action: { moveUp(index: index) }) {
            Image(systemName: "arrow.up")
          }
          .disabled(index == 0)
          .buttonStyle(BorderlessButtonStyle())

          Button(action: { remove(at: index) }) {
            Image(systemName: "minus")
          }
          .buttonStyle(BorderlessButtonStyle())

          Button(action: { add(at: index) }) {
            Image(systemName: "plus")
          }
          .buttonStyle(BorderlessButtonStyle())
        }
      }

      Button(action: { add(at: model.value.count) }) {
        Image(systemName: "plus")
      }
      .buttonStyle(BorderlessButtonStyle())
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private func binding(for id: UUID) -> Binding<T.Storage?> {
    return Binding(
      get: { self.model.value.first { $0.id == id }?.value.value },
      set: { newValue in
        if let newValue = newValue,
          let index = self.model.value.firstIndex(where: { $0.id == id })
        {
          self.model.value[index].value.value = newValue
        }
      }
    )
  }

  private func findElementIndex(_ element: Identified<T>) -> Int {
    // SAFETY: element should be inside the array.
    return model.value.firstIndex(where: { $0.id == element.id })!
  }

  private func add(at index: Int) {
    model.addEmpty(at: index)
  }

  private func remove(at index: Int) {
    model.value.remove(at: index)
  }

  private func moveUp(index: Int) {
    if index > 0 {
      model.value.swapAt(index, index - 1)
    }
  }
}

struct FontOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
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
        }
      }
      .padding()
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

func bundleIdentifier(_ appPath: String) -> String {
  guard let bundle = Bundle(path: appPath) else {
    return ""
  }
  return bundle.bundleIdentifier ?? ""
}

struct AppIMOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  let openPanel = NSOpenPanel()
  @ObservedObject var model: AppIMOption
  @State private var appIcon: NSImage? = nil
  @State private var imNameMap: [String: String] = [:]

  var body: some View {
    HStack {
      if !model.appPath.isEmpty {
        let icon = NSWorkspace.shared.icon(forFile: model.appPath)
        Image(nsImage: icon)
          .padding(.trailing, 8)
      }
      Button(action: openSelector) {
        Text(model.appName.isEmpty ? NSLocalizedString("Select App", comment: "") : model.appName)
      }
      Picker(
        NSLocalizedString("uses", comment: "App X *uses* some input method"),
        selection: $model.imName
      ) {
        ForEach(Array(imNameMap.keys), id: \.self) { key in
          Text(imNameMap[key] ?? "").tag(key)
        }
      }
    }.padding(.bottom, 8)
      .onAppear {
        imNameMap = [:]
        let curGroup = JSON(parseJSON: String(Fcitx.imGetCurrentGroup()))
        for (_, inputMethod) in curGroup {
          let imName = inputMethod["name"].stringValue
          let nativeName = inputMethod["displayName"].stringValue
          imNameMap[imName] = nativeName
        }
      }
  }

  private func openSelector() {
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.allowedContentTypes = [.application]
    openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
    openPanel.begin { response in
      if response == .OK {
        let selectedApp = openPanel.urls.first
        if let appURL = selectedApp {
          let path = appURL.localPath()
          model.appId = bundleIdentifier(path)
          let name = appURL.lastPathComponent
          model.appName = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
          model.appPath = path
        }
      }
    }
  }
}

struct PunctuationMapOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  @ObservedObject var model: PunctuationMapOption

  var body: some View {
    HStack {
      TextField(
        NSLocalizedString("Key", comment: ""),
        text: Binding(
          get: { model.value["Key"] ?? "" },
          set: { model.value["Key"] = $0 }
        ))
      TextField(
        NSLocalizedString("Mapping", comment: ""),
        text: Binding(
          get: { model.value["Mapping"] ?? "" },
          set: { model.value["Mapping"] = $0 }
        ))
      TextField(
        NSLocalizedString("Alternative Mapping", comment: ""),
        text: Binding(
          get: { model.value["AltMapping"] ?? "" },
          set: { model.value["AltMapping"] = $0 }
        ))
    }
  }
}

struct GroupOptionView: OptionView {
  let label: String
  let overrideLabel: String? = nil
  let children: [Config]

  var body: some View {
    Grid(alignment: .topLeading) {
      ForEach(children) { child in
        let subView = buildViewImpl(config: child)
        let subLabel = Text(subView.overrideLabel ?? subView.label)
        if subView is GroupOptionView {
          // If this is a nested group, put it inside a box, and let
          // it span two columns.
          GridRow {
            subLabel
              .font(.title3)
              .gridCellColumns(2)
              .help(NSLocalizedString("Right click to reset this group", comment: ""))
              .contextMenu {
                Button {
                  child.resetToDefault()
                } label: {
                  Text("Reset to default")
                }
              }
          }
          GridRow {
            GroupBox {
              AnyView(subView)
            }.gridCellColumns(2)
          }
        } else {
          // Otherwise, put the label in the left column and the
          // content in the right column.
          GridRow {
            subLabel
              .frame(minWidth: 100, maxWidth: 300, alignment: .trailing)
              .help(NSLocalizedString("Right click to reset this item", comment: ""))
              .contextMenu {
                Button {
                  child.resetToDefault()
                } label: {
                  Text("Reset to default")
                }
              }
            AnyView(subView)
          }
        }
      }
    }
  }
}

struct UnsupportedOptionView: OptionView {
  let label = ""
  let overrideLabel: String? = nil
  let model: any Option

  var body: some View {
    Text("Unsupported option type \(String(describing: model))")
  }
}

func buildViewImpl(label: String, option: any Option) -> any OptionView {
  if let option = option as? BooleanOption {
    return BooleanOptionView(label: label, model: option)
  } else if let option = option as? FontOption {
    return FontOptionView(label: label, model: option)
  } else if let option = option as? AppIMOption {
    return AppIMOptionView(label: label, model: option)
  } else if let option = option as? KeyOption {
    return KeyOptionView(label: label, model: option)
  } else if let option = option as? StringOption {
    return StringOptionView(label: label, model: option)
  } else if let option = option as? ExternalOption {
    return ExternalOptionView(label: label, model: option)
  } else if let option = option as? EnumOption {
    return EnumOptionView(label: label, model: option)
  } else if let option = option as? IntegerOption {
    return IntegerOptionView(label: label, model: option)
  } else if let option = option as? ColorOption {
    return ColorOptionView(label: label, model: option)
  } else if let option = option as? PunctuationMapOption {
    return PunctuationMapOptionView(label: label, model: option)
  } else if let option = option as? ListOption<FontOption> {
    return ListOptionView<FontOption>(label: label, model: option)
  } else if let option = option as? ListOption<AppIMOption> {
    return ListOptionView<AppIMOption>(label: label, model: option)
  } else if let option = option as? ListOption<KeyOption> {
    return ListOptionView<KeyOption>(label: label, model: option)
  } else if let option = option as? ListOption<StringOption> {
    return ListOptionView<StringOption>(label: label, model: option)
  } else if let option = option as? ListOption<EnumOption> {
    return ListOptionView<EnumOption>(label: label, model: option)
  } else if let option = option as? ListOption<PunctuationMapOption> {
    return ListOptionView<PunctuationMapOption>(label: label, model: option)
  } else {
    return UnsupportedOptionView(model: option)
  }
}

func buildViewImpl(config: Config) -> any OptionView {
  switch config.kind {
  case .group(let children):
    return GroupOptionView(label: config.path == "" ? "" : config.description, children: children)
  case .option(let option):
    return buildViewImpl(label: config.description, option: option)
  }
}

func buildView(config: Config) -> AnyView {
  AnyView(buildViewImpl(config: config))
}

let testConfig = Config(
  path: "Fuzzy",
  description: "Fuzzy",
  kind: .group([
    Config(
      path: "AN_ANG", description: "Fuzzy an ang",
      kind: .option(BooleanOption(defaultValue: false, value: true))),
    Config(
      path: "foo", description: "FOOOO!",
      kind: .option(StringOption(defaultValue: "", value: "semicolon"))),
    Config(
      path: "external", description: "External test",
      kind: .option(ExternalOption(option: "Punctuation", external: "fcitx://addon/punctuation"))),
    Config(
      path: "Shuangpin Profile", description: "双拼方案",
      kind: .option(
        EnumOption(
          defaultValue: "Ziranma", value: "MS", enumStrings: ["Ziranma", "MS"],
          enumStringsI18n: ["自然码", "微软"]))),
    Config(
      path: "interval", description: "int test",
      kind: .option(IntegerOption(defaultValue: 0, value: 10, min: 0, max: 1000))),
    // Config(
    //   path: "list", description: "List test",
    //   kind: .option(
    //     ListOption(
    //       defaultValue: ["a", "b", "c"], value: ["c", "d"], elementType: "String"))
    // ),
  ]))

#Preview {
  VStack {
    buildView(config: testConfig)
    Button("Print") {
      print(testConfig.encodeValue())
    }
  }
}
