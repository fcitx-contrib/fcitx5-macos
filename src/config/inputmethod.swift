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

private class ViewModel: ObservableObject {
  @Published var groups = [Group]() {
    didSet {
      save()
    }
  }
  @Published var selectedInputMethod: UUID? {
    didSet {
      updateModel()
    }
  }
  @Published var configModel: Config?
  @Published var errorMsg: String?
  var loading = false
  var uuidToIM = [UUID: String]()

  init() {
    load()
  }

  func load() {
    uuidToIM.removeAll(keepingCapacity: true)
    loading = true
    do {
      let jsonStr = String(Fcitx.imGetGroups())
      if let jsonData = jsonStr.data(using: .utf8) {
        groups = try JSONDecoder().decode([Group].self, from: jsonData)
        for group in groups {
          for im in group.inputMethods {
            uuidToIM[im.id] = im.name
          }
        }
      } else {
        FCITX_ERROR("Couldn't decode input method config")
      }
    } catch {
      FCITX_ERROR("Couldn't load input method config: \(error)")
    }
    loading = false
  }

  func updateModel() {
    guard let uuid = selectedInputMethod else { return }
    guard let im = uuidToIM[uuid] else { return }
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
    if loading {
      return
    }
    do {
      let data = try JSONEncoder().encode(groups)
      if let jsonStr = String(data: data, encoding: .utf8) {
        Fcitx.imSetGroups(jsonStr)
      } else {
        FCITX_ERROR("Couldn't save input method groups: failed to encode data as UTF-8")
      }
    } catch {
      FCITX_ERROR("Couldn't save input method groups: \(error)")
    }
  }
}

struct InputMethodConfigView: View {
  @StateObject private var viewModel = ViewModel()

  var body: some View {
    NavigationSplitView {
      VStack {
        List(selection: $viewModel.selectedInputMethod) {
          ForEach($viewModel.groups) { $group in
            let header = Text(group.name)
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
              .contextMenu {
                Button("Rename group") {}
                Button("Add input method") {}
                Button("Remove group") {}
              }
            Section(header: header) {
              ForEach($group.inputMethods) { $inputMethod in
                Text(inputMethod.displayName)
                  .contextMenu {
                    Button("Remove input method") {}
                  }
              }
              .onMove { indices, newOffset in
                group.inputMethods.move(fromOffsets: indices, toOffset: newOffset)
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
