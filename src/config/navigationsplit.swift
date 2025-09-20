import Fcitx
import Logging
import SwiftUI

struct ListConfigView: View {
  private let path: String
  private let key: String
  @ObservedObject private var viewModel: ListConfigViewModel
  @State private var dummyText = ""

  init(_ path: String, key: String) {
    self.path = path
    self.key = key
    viewModel = ListConfigViewModel(path)
  }

  func refresh() {
    viewModel.load()
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedConfigIndex) {
        ForEach(0..<viewModel.configs.count, id: \.self) { i in
          Text(viewModel.configs[i].description)
        }
      }
    } detail: {
      if key == "theme" {
        TextField(NSLocalizedString("Type here to preview style", comment: ""), text: $dummyText)
          .padding([.top, .leading, .trailing])
      }
      ScrollView {
        if let config = viewModel.selectedConfig {
          buildView(config: config).padding()
        }
      }.padding([.top], 1)  // Cannot be 0 otherwise content overlaps with title bar.
      footer(
        reset: {
          // Reset only current page.
          viewModel.selectedConfig?.resetToDefault()
        },
        apply: {
          // Save all pages.
          Fcitx.setConfig("fcitx://\(path)", viewModel.config?.encodeValue())
          viewModel.load()  // Need updated color/size after selecting a theme.
        },
        close: {
          FcitxInputController.controllers[key]?.window?.performClose(_: nil)
        })
    }
  }
}

class ListConfigViewModel: ObservableObject {
  private let path: String
  @Published var config: Config?
  @Published var configs = [Config]()
  @Published var selectedConfig: Config?
  @Published var selectedConfigIndex: Int? = 0 {
    didSet {
      updateConfig()
    }
  }

  init(_ path: String) {
    self.path = path
  }

  func load() {
    do {
      config = try getConfig(uri: "fcitx://\(path)")
      switch config!.kind {
      case .group(let children):
        configs = children
      case .option:
        FCITX_ERROR("Invalid config type")
      }
    } catch {
      FCITX_ERROR("Cannot load \(path): \(error)")
    }
    updateConfig()
  }

  private func updateConfig() {
    if let index = selectedConfigIndex {
      selectedConfig = configs[index]
    }
  }
}
