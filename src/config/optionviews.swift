import Fcitx
import Logging
import SwiftUI

struct BooleanOptionView: View {
  let label: String
  @ObservedObject var model: BooleanOption
  var body: some View {
    Toggle(isOn: $model.value) {
      Text(label)
    }
  }
}

struct StringOptionView: View {
  let label: String
  @ObservedObject var model: StringOption
  var body: some View {
    TextField(text: $model.value) {
      Text(label)
    }
  }
}

struct IntegerOptionView: View {
  let label: String
  @ObservedObject var model: IntegerOption
  let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.allowsFloats = false
    formatter.usesGroupingSeparator = false
    return formatter
  }()
  var body: some View {
    ZStack(alignment: .trailing) {
      TextField(label, value: $model.value, formatter: numberFormatter)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onChange(of: model.value) { newValue in
          if let max = model.max,
            newValue > max
          {
            model.value = max
          } else if let min = model.min,
            newValue < min
          {
            model.value = min
          }
        }
        .padding(.trailing, 60)
      HStack(spacing: 0) {
        Button {
          model.value -= 1
        } label: {
          Image(systemName: "minus")
        }
        Button {
          model.value += 1
        } label: {
          Image(systemName: "plus")
        }
      }
    }
  }
}

struct ExternalOptionView: View {
  let label: String
  let model: ExternalOption

  @StateObject private var viewModel = ViewModel()

  var body: some View {
    Button(label) {
      switch model.option {
      case "UserDataDir":
        let rimeUserDir = FileManager.default.homeDirectoryForCurrentUser
          .appendingPathComponent(".local")
          .appendingPathComponent("share")
          .appendingPathComponent("fcitx5")
          .appendingPathComponent("rime")
        mkdirP(rimeUserDir.path())
        NSWorkspace.shared.open(rimeUserDir)
      default:
        viewModel.showConfig(model.external)
      }
    }
    .sheet(isPresented: $viewModel.hasConfig) {
      VStack {
        ScrollView([.horizontal, .vertical]) {
          buildView(config: viewModel.externalConfig!)
        }
        HStack {
          Button("Save") {
            viewModel.saveExternalConfig(model.external)
          }
          Button("Close") {
            viewModel.externalConfig = nil
          }
        }
      }
      .padding()
      .frame(minWidth: 400)
    }
    .alert(
      "Error",
      isPresented: $viewModel.hasError,
      presenting: ()
    ) { _ in
      Button("OK") {
        viewModel.errorMsg = nil
      }
    } message: { _ in
      Text(viewModel.errorMsg!)
    }
  }

  private class ViewModel: ObservableObject {
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
        errorMsg = "Cannot show external config: \(error.localizedDescription)"
      }
    }

    func saveExternalConfig(_ uri: String) {
      if !uri.hasPrefix("fcitx://config") { return }
      guard let config = externalConfig else { return }
      Fcitx.setConfig(uri, config.encodeValue())
    }
  }
}

struct EnumOptionView: View {
  let label: String
  @ObservedObject var model: EnumOption
  var body: some View {
    Picker(label, selection: $model.value) {
      ForEach(0..<model.enumStrings.count, id: \.self) { i in
        Text(model.enumStringsI18n[i]).tag(model.enumStrings[i])
      }
    }
  }
}

struct StringListOptionView: View {
  let label: String
  @ObservedObject var model: ListOption<String>

  var body: some View {
    LabeledContent(label) {
      VStack {
        ForEach(model.value) { element in
          HStack {
            TextField("", text: binding(for: element.id))
              .frame(maxWidth: .infinity, alignment: .leading)

            let index = findElementIndex(element)
            Button(action: { moveUp(index: index) }) {
              Image(systemName: "arrow.up")
            }
            .disabled(index == 0)
            .buttonStyle(BorderlessButtonStyle())

            Button(action: { moveDown(index: index) }) {
              Image(systemName: "arrow.down")
            }
            .disabled(index == model.value.count - 1)
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
  }

  private func binding(for id: UUID) -> Binding<String> {
    return Binding(
      get: { self.model.value.first { $0.id == id }?.value ?? "" },
      set: { newValue in
        if let index = self.model.value.firstIndex(where: { $0.id == id }) {
          self.model.value[index].value = newValue
        }
      }
    )
  }

  private func findElementIndex(_ element: Identified<String>) -> Int {
    // SAFETY: element should be inside the array.
    return model.value.firstIndex(where: { $0.id == element.id })!
  }

  private func add(at index: Int) {
    model.value.insert(Identified(value: ""), at: index)
  }

  private func remove(at index: Int) {
    model.value.remove(at: index)
  }

  private func moveUp(index: Int) {
    if index > 0 {
      model.value.swapAt(index, index - 1)
    }
  }

  private func moveDown(index: Int) {
    if index < model.value.count - 1 {
      model.value.swapAt(index, index + 1)
    }
  }
}

func buildViewImpl(config: Config) -> any View {
  switch config.kind {
  case .group(let children):
    let form = Form {
      ForEach(children) { child in
        buildView(config: child)
      }
    }
    if config.path == "" {
      // Top-level group
      return form
    } else {
      // A subgroup.
      return LabeledContent(config.description) {
        GroupBox {
          form.padding()
        }
      }
    }

  case .option(let option):
    if let option = option as? BooleanOption {
      return BooleanOptionView(label: config.description, model: option)
    } else if let option = option as? StringOption {
      return StringOptionView(label: config.description, model: option)
    } else if let option = option as? ExternalOption {
      return ExternalOptionView(label: config.description, model: option)
    } else if let option = option as? EnumOption {
      return EnumOptionView(label: config.description, model: option)
    } else if let option = option as? IntegerOption {
      return IntegerOptionView(label: config.description, model: option)
    } else if let option = option as? ListOption<String> {
      return StringListOptionView(label: config.description, model: option)
    } else {
      return Text("Unsupported option type \(String(describing: option))")
    }
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
    Config(
      path: "list", description: "List test",
      kind: .option(
        ListOption(defaultValue: ["a", "b", "c"], value: ["c", "d"], elementType: "String"))
    ),
  ]))

#Preview {
  VStack {
    buildView(config: testConfig)
    Button("Print") {
      print(testConfig.encodeValue())
    }
  }
}
