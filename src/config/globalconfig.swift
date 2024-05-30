import Fcitx
import Logging
import SwiftUI

class GlobalConfigController: ConfigWindowController {
  let view = GlobalConfigView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Global Config", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }

  func refresh() {
    view.refresh()
  }
}

struct GlobalConfigView: View {
  @ObservedObject private var viewModel = GlobalConfigViewModel()

  var body: some View {
    VStack {
      ScrollView {
        if viewModel.globalConfig != nil {
          buildView(config: viewModel.globalConfig!).padding([.top, .leading, .trailing])
        }
      }

      footer(
        reset: {
          viewModel.globalConfig?.resetToDefault()
        },
        apply: {
          Fcitx.setConfig("fcitx://config/global", viewModel.globalConfig?.encodeValue())
        },
        close: {
          FcitxInputController.globalConfigController.window?.performClose(_: nil)
        })
    }
  }

  func refresh() {
    viewModel.load()
  }
}

class GlobalConfigViewModel: ObservableObject {
  @Published var globalConfig: Config?

  func load() {
    do {
      globalConfig = try getGlobalConfig()
    } catch {
      FCITX_ERROR("Cannot load global config: \(error)")
    }
  }
}
