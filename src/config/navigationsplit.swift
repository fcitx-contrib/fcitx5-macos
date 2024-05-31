import Fcitx
import Logging
import SwiftUI

struct ListConfigView: View {
  private let path: String
  private let key: String
  @ObservedObject private var viewModel: ListConfigViewModel

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
      ScrollView {
        if viewModel.selectedConfig != nil {
          buildView(config: viewModel.selectedConfig!).padding([.top, .leading, .trailing])
        }
      }
    }
    footer(
      reset: {
        viewModel.config?.resetToDefault()
      },
      apply: {
        Fcitx.setConfig("fcitx://\(path)", viewModel.config?.encodeValue())
      },
      close: {
        FcitxInputController.controllers[key]?.window?.performClose(_: nil)
      })
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
