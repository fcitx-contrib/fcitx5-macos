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
      viewModel.showConfig(model.external)
    }
    .sheet(isPresented: $viewModel.hasConfig) {
      VStack {
        ScrollView([.horizontal, .vertical]) {
          buildView(config: viewModel.externalConfig!)
        }
        Button("Hide") {
          viewModel.externalConfig = nil
        }
      }
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

struct ListOptionView: View {
  let label: String
  @ObservedObject var model: ListOption<String>
  var body: some View {
    LabeledContent(label) {
      ForEach(0..<model.value.count, id: \.self) { index in
        Text(model.value[index])
      }
    }
  }
}

func buildViewImpl(config: Config) -> any View {
  switch config.kind {
  case .group(let children):
    Form {
      Section(config.description) {
        ForEach(children) { child in
          buildView(config: child)
        }
      }
    }
  case .option(let option):
    if let option = option as? BooleanOption {
      BooleanOptionView(label: config.description, model: option)
    } else if let option = option as? StringOption {
      StringOptionView(label: config.description, model: option)
    } else if let option = option as? ExternalOption {
      ExternalOptionView(label: config.description, model: option)
    } else if let option = option as? EnumOption {
      EnumOptionView(label: config.description, model: option)
    } else if let option = option as? IntegerOption {
      IntegerOptionView(label: config.description, model: option)
    } else if let option = option as? ListOption<String> {
      ListOptionView(label: config.description, model: option)
    } else {
      Text("Unsupported option type \(String(describing: option))")
    }
  }
}

func buildView(config: Config) -> AnyView {
  AnyView(buildViewImpl(config: config))
}

let testConfig = Config(
  path: "Fuzzy",
  description: "Fuzzy",
  sortKey: 0,
  kind: .group([
    Config(
      path: "AN_ANG", description: "Fuzzy an ang", sortKey: 1,
      kind: .option(BooleanOption(defaultValue: false, value: true))),
    Config(
      path: "foo", description: "FOOOO!", sortKey: 2,
      kind: .option(StringOption(defaultValue: "", value: "semicolon"))),
    Config(
      path: "external", description: "External test", sortKey: 3,
      kind: .option(ExternalOption(external: "fcitx://addon/punctuation"))),
    Config(
      path: "Shuangpin Profile", description: "双拼方案", sortKey: 4,
      kind: .option(
        EnumOption(
          defaultValue: "Ziranma", value: "MS", enumStrings: ["Ziranma", "MS"],
          enumStringsI18n: ["自然码", "微软"]))),
    Config(
      path: "interval", description: "int test", sortKey: 5,
      kind: .option(IntegerOption(defaultValue: 0, value: 10, min: 0, max: 1000))),
    Config(
      path: "list", description: "List test", sortKey: 6,
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
