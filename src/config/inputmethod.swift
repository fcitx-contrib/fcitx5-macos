import Fcitx
import Logging
import SwiftUI

class InputMethodConfigController: NSWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable, .resizable, .utilityWindow],
      backing: .buffered, defer: false)
    window.title = "Input Methods"
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: InputMethodConfigView())
  }
}

private struct Group: Identifiable, Codable {
  var name: String
  var inputMethods: [InputMethod]
  let id = UUID()

  private enum CodingKeys: CodingKey {
    case name
    case inputMethods
  }
}

private struct InputMethod: Identifiable, Codable {
  var name: String
  var displayName: String
  let id = UUID()

  private enum CodingKeys: CodingKey {
    case name
    case displayName
  }
}

@Observable
private class ViewModel {
  var groups = [Group]()
  var selectedInputMethod: String? {
    didSet {
      updateModel()
    }
  }
  var configModel: Config?
  var errorMsg: String?

  init() {
    load()
  }

  func load() {
    do {
      let jsonStr = String(all_input_methods())
      if let jsonData = jsonStr.data(using: .utf8) {
        groups = try JSONDecoder().decode([Group].self, from: jsonData)
      } else {
        FCITX_ERROR("Couldn't decode input method config")
      }
    } catch {
      FCITX_ERROR("Couldn't load input method config: \(error)")
    }
  }

  func updateModel() {
    guard let im = selectedInputMethod else { return }
    do {
      configModel = try getConfig(im: im)
      errorMsg = nil
    } catch {
      configModel = nil
      errorMsg = error.localizedDescription
      FCITX_ERROR("Couldn't build config view: \(error)")
    }
  }

  func save() {
    // TODO
  }
}

struct InputMethodConfigView: View {
  @State private var viewModel = ViewModel()

  var body: some View {
    NavigationSplitView {
      VStack {
        List(selection: $viewModel.selectedInputMethod) {
          ForEach($viewModel.groups, id: \.name) { $group in
            let header = Text(group.name)
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
              .contextMenu {
                Button("Rename group") {}
                Button("Add input method") {}
                Button("Remove group") {}
              }
            Section(header: header) {
              ForEach($group.inputMethods, id: \.name) { $inputMethod in
                Text(inputMethod.displayName)
                  .contextMenu {
                    Button("Remove input method") {}
                  }
              }
              .onMove { indices, newOffset in
                viewModel.groups.move(fromOffsets: indices, toOffset: newOffset)
              }
            }
          }
          .onMove { indices, newOffset in
            viewModel.groups.move(fromOffsets: indices, toOffset: newOffset)
          }
        }
        .contextMenu {
          Button("Add group") {}
        }
      }
    } detail: {
      if let selectedInputMethod = viewModel.selectedInputMethod {
        if let configModel = viewModel.configModel {
          ScrollView([.vertical, .horizontal]) {
            buildView(config: configModel)
          }
          .defaultScrollAnchor(.topTrailing)
        } else if let errorMsg = viewModel.errorMsg {
          Text("Cannot show config for \(selectedInputMethod): \(errorMsg)")
        }
      } else {
        Text("Select an input method from the side bar.")
      }
    }
  }
}

#Preview {
  InputMethodConfigView()
}
