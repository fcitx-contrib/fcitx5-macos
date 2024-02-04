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
  var inputMethods: [GroupItem]
  let id = UUID()

  private enum CodingKeys: CodingKey {
    case name, inputMethods
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    inputMethods = (try? container.decode([GroupItem].self, forKey: .inputMethods)) ?? []
  }

  init(name: String, inputMethods: [GroupItem]) {
    self.name = name
    self.inputMethods = inputMethods
  }
}

private struct GroupItem: Identifiable, Codable {
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
  @Published var selectedItem: UUID? {
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
        errorMsg = "Couldn't decode input method config: not UTF-8"
        FCITX_ERROR("Couldn't decode input method config: not UTF-8")
      }
    } catch {
      errorMsg = "Couldn't load input method config: \(error)"
      FCITX_ERROR("Couldn't load input method config: \(error)")
    }
    loading = false
  }

  func updateModel() {
    guard let uuid = selectedItem else { return }
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

  func addGroup(_ name: String) {
    if name == "" || groups.contains(where: { $0.name == name }) {
      return
    }
    groups.append(Group(name: name, inputMethods: []))
  }

  func removeGroup(_ name: String) {
    if groups.count <= 1 {
      return
    }
    groups.removeAll(where: { $0.name == name })
  }

  func renameGroup(_ group: inout Group, _ name: String) {
    if name == "" {
      return
    }
    group.name = name
  }

  func removeItem(_ group: inout Group, _ uuid: UUID) {
    group.inputMethods.removeAll(where: { $0.id == uuid })
  }
}

struct InputMethodConfigView: View {
  @StateObject private var viewModel = ViewModel()
  @StateObject var addGroupDialog = InputDialog(title: "Add an empty group", prompt: "Group name")
  @StateObject var renameGroupDialog = InputDialog(title: "Rename group", prompt: "Group name")

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedItem) {
        ForEach($viewModel.groups) { $group in
          let header = Text(group.name)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu {
              Button("Rename group") {
                renameGroupDialog.show { input in
                  viewModel.renameGroup(&group, input)
                }
              }
              }
              Button("Remove group") {
                viewModel.removeGroup(group.name)
              }
            }
            .sheet(isPresented: $renameGroupDialog.presented) {
              renameGroupDialog.view()
            }
            }
          Section(header: header) {
            ForEach($group.inputMethods) { $inputMethod in
              Text(inputMethod.displayName)
                .contextMenu {
                  Button("Remove input method") {
                    viewModel.removeItem(&group, inputMethod.id)
                  }
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
        Button("Add group") {
          addGroupDialog.show { input in
            viewModel.addGroup(input)
          }
        }
      }
      .sheet(isPresented: $addGroupDialog.presented) {
        addGroupDialog.view()
      }
    } detail: {
      if let selectedItem = viewModel.selectedItem {
        if let configModel = viewModel.configModel {
          ScrollView([.vertical, .horizontal]) {
            buildView(config: configModel)
          }
          .defaultScrollAnchor(.topTrailing)
        } else if let errorMsg = viewModel.errorMsg {
          Text("Cannot show config for \(selectedItem): \(errorMsg)")
        }
      } else {
        Text("Select an input method from the side bar.")
      }
    }
  }
}

/// A common modal dialog view-model + view builder for getting user
/// input.
///
/// The basic pattern is:
/// 1. define a StateObject for the dialog:
/// ```
/// @StateObject private var myDialog = InputDialog(title: "Title", prompt: "Some string")
/// ```
/// 2. Add the dialog view as a sheet to view:
/// ```
/// view.sheet(isPresented: $myDialog.presented) { myDialog.view() }
/// ```
/// 3. When you want to ask for user input, use `myDialog.show` and
/// pass in a callback to handle the user input:
/// ```
/// Button("Click me") {
///   myDialog.show() { userInput in
///     print("You input: \(userInput)")
///   }
/// }
/// ```
class InputDialog: ObservableObject {
  @Published var presented = false
  @Published var userInput = ""
  let title: String
  let prompt: String
  var continuation: ((String) -> Void)?

  init(title: String, prompt: String) {
    self.title = title
    self.prompt = prompt
  }

  func show(_ continuation: @escaping (String) -> Void) {
    self.continuation = continuation
    presented = true
  }

  @ViewBuilder
  func view() -> some View {
    let myBinding = Binding(
      get: { self.userInput },
      set: { self.userInput = $0 }
    )
    VStack {
      TextField(title, text: myBinding)
      HStack {
        Button("OK") {
          if let cont = self.continuation {
            cont(self.userInput)
          }
          self.presented = false
        }
        Button("Cancel") {
          self.presented = false
        }
      }
    }.padding()
  }
}

#Preview {
  InputMethodConfigView()
}
