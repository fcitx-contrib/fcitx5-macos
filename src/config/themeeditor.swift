import Fcitx
import Logging
import SwiftUI

class ThemeEditorController: ConfigWindowController {
  let view = ThemeEditorView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Theme Editor", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.titlebarAppearsTransparent = true
    attachToolbar(window)
  }

  func refresh() {
    view.refresh()
  }
}

struct ThemeEditorView: View {
  @ObservedObject private var viewModel = ThemeEditorViewModel()

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedConfigIndex) {
        ForEach(0..<viewModel.configs.count, id: \.self) { i in
          Text(viewModel.configs[i].description)
        }
      }
    } detail: {
      ScrollView([.vertical]) {
        if viewModel.selectedConfig != nil {
          buildView(config: viewModel.selectedConfig!).padding([.leading, .trailing])
        }
      }.padding([.top])
    }
    footer(
      reset: {
        viewModel.config?.resetToDefault()
      },
      apply: {
        Fcitx.setConfig("fcitx://config/addon/webpanel/", viewModel.config?.encodeValue())
      },
      close: {
        FcitxInputController.themeEditorController.window?.performClose(_: nil)
      })
  }

  func refresh() {
    viewModel.load()
  }
}

class ThemeEditorViewModel: ObservableObject {
  @Published var config: Config?
  @Published var configs = [Config]()
  @Published var selectedConfig: Config?
  @Published var selectedConfigIndex: Int? = 0 {
    didSet {
      updateConfig()
    }
  }

  func load() {
    do {
      config = try getConfig(addon: "webpanel")
      switch config!.kind {
      case .group(let children):
        configs = children
      case .option:
        FCITX_ERROR("Invalid config type")
      }
    } catch {
      FCITX_ERROR("Error loading theme editor config: \(error)")
    }
    updateConfig()
  }

  private func updateConfig() {
    if let index = selectedConfigIndex {
      selectedConfig = configs[index]
    }
  }
}
