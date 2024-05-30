import Fcitx
import Logging
import SwiftUI

class AddonConfigController: ConfigWindowController {
  let view = AddonConfigView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Addon Config", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }

  func refresh() {
    view.refresh()
  }
}

private struct Addon: Codable, Identifiable {
  let name: String
  let id: String
  let comment: String
  let isConfigurable: Bool
}

private struct Category: Codable, Identifiable {
  let name: String
  let id: Int
  let addons: [Addon]
}

private struct AddonRowView: View {
  var addon: Addon
  @StateObject private var viewModel = ExternalConfigViewModel()

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(addon.name).font(.headline)
        if addon.isConfigurable {
          Spacer()
          Button(
            NSLocalizedString("Setting", comment: ""), systemImage: "gearshape", action: openSetting
          ).labelStyle(.iconOnly)
            .sheet(isPresented: $viewModel.hasConfig) {
              VStack {
                ScrollView([.vertical]) {
                  buildView(config: viewModel.externalConfig!)
                }
                footer(
                  reset: {
                    viewModel.externalConfig?.resetToDefault()
                  }, apply: save,
                  close: {
                    viewModel.externalConfig = nil
                  })
              }
              .padding()
              .frame(minWidth: 400)
            }
        }
      }
      if !addon.comment.isEmpty {
        Text(addon.comment)
      }
    }.padding()
  }

  private func save() {
    viewModel.saveExternalConfig("fcitx://config/addon/\(addon.id)/")
  }

  private func openSetting() {
    viewModel.showConfig("fcitx://config/addon/\(addon.id)/")
  }
}

struct AddonConfigView: View {
  @ObservedObject private var viewModel = ViewModel()

  var body: some View {
    List {
      ForEach(viewModel.categories) { category in
        Section(header: Text(category.name)) {
          ForEach(category.addons) { addon in
            AddonRowView(addon: addon)
          }
        }
      }
    }
  }

  func refresh() {
    viewModel.load()
  }

  private class ViewModel: ObservableObject {
    @Published var categories = [Category]()
    @Published var hasError = false
    var errorMsg: String? {
      didSet {
        hasError = (errorMsg != nil)
      }
    }

    func load() {
      do {
        let jsonStr = String(Fcitx.getAddons())
        if let jsonData = jsonStr.data(using: .utf8) {
          categories = try JSONDecoder().decode([Category].self, from: jsonData)
        } else {
          errorMsg = "Couldn't decode addon config: not UTF-8"
          FCITX_ERROR(errorMsg!)
        }
      } catch {
        errorMsg = "Couldn't load addon config: \(error)"
        FCITX_ERROR(errorMsg!)
      }
    }
  }
}
