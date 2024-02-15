import Fcitx
import Logging
import SwiftUI

class InputMethodConfigController: ConfigWindowController {
  let view = InputMethodConfigView()
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = "Input Methods"
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.level = .floating
    window.titlebarAppearsTransparent = true
    window.toolbar?.showsBaselineSeparator = false
    window.toolbarStyle = .unified
  }

  func refresh() {
    view.refresh()
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

struct InputMethodConfigView: View {
  @ObservedObject private var viewModel = ViewModel()
  @StateObject var addGroupDialog = InputDialog(title: "Add an empty group", prompt: "Group name")
  @StateObject var renameGroupDialog = InputDialog(title: "Rename group", prompt: "Group name")

  @State var addingInputMethod = false
  @State var inputMethodsToAdd = Set<InputMethod>()
  @State fileprivate var addToGroup: Group?

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedItem) {
        ForEach($viewModel.groups) { $group in
          let header = Text(group.name)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu {
              Button("Rename group \(group.name)") {
                renameGroupDialog.show { input in
                  viewModel.renameGroup(&group, input)
                }
              }
              Button("Add input method to \(group.name)") {
                addToGroup = group
                addingInputMethod = true
              }
              Button("Remove group \(group.name)") {
                viewModel.removeGroup(group.name)
              }
            }
            .sheet(isPresented: $renameGroupDialog.presented) {
              renameGroupDialog.view()
            }
            .sheet(isPresented: $addingInputMethod) {
              VStack {
                AvailableInputMethodView(
                  selection: $inputMethodsToAdd,
                  addToGroup: $addToGroup)
                HStack {
                  Button("Add") {
                    if let groupName = addToGroup?.name {
                      viewModel.addItems(groupName, inputMethodsToAdd)
                    }
                    addingInputMethod = false
                    inputMethodsToAdd = Set()
                  }
                  Button("Cancel") {
                    addingInputMethod = false
                    inputMethodsToAdd = Set()
                  }
                }
              }.padding()
            }
          Section(header: header) {
            ForEach($group.inputMethods) { $inputMethod in
              Text(inputMethod.displayName)
                .contextMenu {
                  Button("Remove input method") {
                    viewModel.removeItem(group.name, inputMethod.id)
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
        Button("Refresh") {
          viewModel.load()
        }
      }
      .sheet(isPresented: $addGroupDialog.presented) {
        addGroupDialog.view()
      }
    } detail: {
      if let selectedItem = viewModel.selectedItem {
        if let configModel = viewModel.configModel {
          VStack {
            let scrollView = ScrollView([.vertical, .horizontal]) {
              buildView(config: configModel)
            }
            if #available(macOS 14.0, *) {
              scrollView.defaultScrollAnchor(.topTrailing)
            } else {
              scrollView
            }
            Button("Save") {
              if let name = viewModel.selectedIMName {
                setConfig("fcitx://config/inputmethod/\(name)", configModel.encodeValue())
              }
            }
          }.padding()
        } else if let errorMsg = viewModel.errorMsg {
          Text("Cannot show config for \(selectedItem): \(errorMsg)")
        }
      } else {
        Text("Select an input method from the side bar.")
      }
    }
  }

  func refresh() {
    viewModel.load()
  }

  private class ViewModel: ObservableObject {
    @Published var groups = [Group]()
    @Published var selectedItem: UUID? {
      didSet {
        configModel = nil
        updateModel()
        if let uuid = selectedItem {
          selectedIMName = uuidToIM[uuid]
        }
      }
    }
    @Published var selectedIMName: String?
    @Published var configModel: Config?
    @Published var errorMsg: String?
    var uuidToIM = [UUID: String]()

    func load() {
      groups = []
      configModel = nil
      selectedItem = nil
      uuidToIM.removeAll(keepingCapacity: true)
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
      selectCurrentIM()
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
      do {
        let data = try JSONEncoder().encode(groups)
        if let jsonStr = String(data: data, encoding: .utf8) {
          Fcitx.imSetGroups(jsonStr)
        } else {
          FCITX_ERROR("Couldn't save input method groups: failed to encode data as UTF-8")
        }
        load()
      } catch {
        FCITX_ERROR("Couldn't save input method groups: \(error)")
      }
    }

    func selectCurrentIM() {
      let groupName = String(Fcitx.imGetCurrentGroupName())
      let imName = String(imGetCurrentIMName())
      // Search for imName in groupName.
      for group in groups {
        if group.name == groupName {
          for item in group.inputMethods {
            if item.name == imName {
              selectedItem = item.id
              return
            }
          }
        }
      }
    }

    func addGroup(_ name: String) {
      if name == "" || groups.contains(where: { $0.name == name }) {
        return
      }
      groups.append(Group(name: name, inputMethods: []))
      save()
    }

    func removeGroup(_ name: String) {
      if groups.count <= 1 {
        return
      }
      DispatchQueue.main.async {
        self.groups = self.groups.filter({ $0.name != name })
        self.save()
      }
    }

    func renameGroup(_ group: inout Group, _ name: String) {
      if name == "" {
        return
      }
      group.name = name
      save()
    }

    func removeItem(_ groupName: String, _ uuid: UUID) {
      DispatchQueue.main.async {
        for i in 0..<self.groups.count {
          if self.groups[i].name == groupName {
            self.groups[i].inputMethods.removeAll(where: { $0.id == uuid })
            break
          }
        }
        self.save()
      }
    }

    func addItems(_ groupName: String, _ ims: Set<InputMethod>) {
      DispatchQueue.main.async {
        for i in 0..<self.groups.count {
          if self.groups[i].name == groupName {
            for im in ims {
              let item = GroupItem(name: im.uniqueName, displayName: im.displayName)
              self.groups[i].inputMethods.append(item)
              self.uuidToIM[item.id] = item.name
            }
          }
        }
        self.save()
      }
    }
  }
}

struct InputMethod: Codable, Hashable {
  let name: String
  let nativeName: String
  let uniqueName: String
  let languageCode: String
  let icon: String
  let isConfigurable: Bool

  var displayName: String {
    if nativeName != "" {
      nativeName
    } else if name != "" {
      name
    } else {
      uniqueName
    }
  }
}

struct AvailableInputMethodView: View {
  @Binding var selection: Set<InputMethod>
  @Binding fileprivate var addToGroup: Group?
  @StateObject private var viewModel = ViewModel()

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedLanguageCode) {
        ForEach(viewModel.languages(), id: \.code) { language in
          Text(language.localized)
        }
      }
    } detail: {
      // Input methods for this language
      if let selectedLanguageCode = viewModel.selectedLanguageCode {
        List(selection: $selection) {
          if let ims = viewModel.availableIMs[selectedLanguageCode] {
            let alreadyEnabled = enabledIMs()
            let newAvailable = ims.filter { !alreadyEnabled.contains($0.uniqueName) }
            ForEach(newAvailable, id: \.self) { im in
              Text(im.displayName)
            }
          } else {
            Text("Error: Unknown language code \(selectedLanguageCode). Please report a bug!")
          }
        }
      } else {
        Text("Select a language from the left list.")
      }
    }
    .frame(minWidth: 640, minHeight: 480)
    .onAppear {
      viewModel.refresh()
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

  func enabledIMs() -> Set<String> {
    return Set(addToGroup?.inputMethods.map { $0.name } ?? [])
  }

  private class ViewModel: ObservableObject {
    @Published var availableIMs = [String: [InputMethod]]()
    @Published var hasError = false
    @Published var selectedLanguageCode: String?
    var errorMsg: String? {
      didSet {
        hasError = (errorMsg != nil)
      }
    }

    func refresh() {
      availableIMs.removeAll()
      let jsonStr = String(Fcitx.imGetAvailableIMs())
      if let jsonData = jsonStr.data(using: .utf8) {
        do {
          let array = try JSONDecoder().decode([InputMethod].self, from: jsonData)
          for im in array {
            if var imList = availableIMs[im.languageCode] {
              imList.append(im)
              availableIMs[im.languageCode] = imList
            } else {
              availableIMs[im.languageCode] = [im]
            }
          }
        } catch {
          errorMsg = "Cannot parse json: \(error.localizedDescription)"
        }
      } else {
        errorMsg = "Cannot decode json string into UTF-8 data"
      }
    }

    fileprivate struct LocalizedLanguageCode: Comparable {
      let code: String
      let localized: String

      init(code: String) {
        self.code = code
        if code == "" {
          localized = "Unknown"
        } else {
          let locale = Locale.current
          let s = locale.localizedString(forIdentifier: code) ?? ""
          localized = s != "" ? s : "Unknown - \(code)"
        }
      }

      public static func < (lhs: Self, rhs: Self) -> Bool {
        let curIdent = Locale.current.identifier.prefix(2)
        if lhs.code.prefix(2) == curIdent {
          return true
        } else if rhs.code.prefix(2) == curIdent {
          return false
        } else {
          return lhs.localized.localizedCompare(rhs.localized) == .orderedAscending
        }
      }
    }

    fileprivate func languages() -> [LocalizedLanguageCode] {
      return Array(availableIMs.keys)
        .map { LocalizedLanguageCode(code: $0) }
        .sorted()
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
