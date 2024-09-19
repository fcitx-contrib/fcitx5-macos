import AlertToast
import Fcitx
import Logging
import SwiftUI

class InputMethodConfigController: ConfigWindowController {
  let view = InputMethodConfigView()
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: styleMask,
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Input Methods", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.level = .floating
    window.titlebarAppearsTransparent = true
    attachToolbar(window)
  }

  func refresh() {
    view.refresh()
  }
}

private struct Group: Codable {
  var name: String
  var inputMethods: [GroupItem]
}

private struct GroupItem: Identifiable, Codable {
  let name: String
  let displayName: String
  let id = UUID()
}

struct InputMethodConfigView: View {
  @ObservedObject private var viewModel = ViewModel()
  @StateObject var addGroupDialog = InputDialog(
    title: NSLocalizedString("Add an empty group", comment: "dialog title"),
    prompt: NSLocalizedString("Group name", comment: "dialog prompt"))
  @StateObject var renameGroupDialog = InputDialog(
    title: NSLocalizedString("Rename group", comment: "dialog title"),
    prompt: NSLocalizedString("Group name", comment: "dialog prompt"))

  @State var addingInputMethod = false
  @State var inputMethodsToAdd = Set<InputMethod>()
  @State fileprivate var addToGroup: Group?
  @State var mouseHoverIMID: UUID?

  @State private var showImportTable = false
  @State private var importTableErrorMsg = ""
  @State private var showImportTableError = false

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedItem) {
        ForEach($viewModel.groups, id: \.name) { $group in
          let header = HStack {
            Text(group.name)

            Button {
              addToGroup = group
              addingInputMethod = true
            } label: {
              Image(systemName: "plus.circle")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(NSLocalizedString("Add input methods to", comment: "") + " '\(group.name)'")

            Button {
              renameGroupDialog.show { input in
                viewModel.renameGroup(&group, input)
              }
            } label: {
              Image(systemName: "pencil")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(NSLocalizedString("Rename", comment: "") + " '\(group.name)'")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .contextMenu {
            Button(NSLocalizedString("Remove", comment: "") + " '\(group.name)'") {
              viewModel.removeGroup(group.name)
            }
          }

          Section(header: header) {
            ForEach($group.inputMethods) { $inputMethod in
              HStack {
                Text(inputMethod.displayName)
                Spacer()
                if mouseHoverIMID == inputMethod.id {
                  Button {
                    viewModel.removeItem(group.name, inputMethod.id)
                  } label: {
                    Image(systemName: "minus")
                      .frame(maxHeight: .infinity)
                      .contentShape(Rectangle())
                  }
                  .buttonStyle(BorderlessButtonStyle())
                  .frame(alignment: .trailing)
                }
              }
              .onHover { hovering in
                mouseHoverIMID = hovering ? inputMethod.id : nil
              }
            }
            .onMove { indices, newOffset in
              group.inputMethods.move(fromOffsets: indices, toOffset: newOffset)
              viewModel.save()
            }
          }
        }
      }
      .contextMenu {
        Button(NSLocalizedString("Add group", comment: "")) {
          addGroupDialog.show { input in
            viewModel.addGroup(input)
          }
        }
        Button(NSLocalizedString("Refresh", comment: "")) {
          viewModel.load()
        }
      }
    } detail: {
      if let selectedItem = viewModel.selectedItem {
        if let configModel = viewModel.configModel {
          VStack {
            let scrollView = ScrollView([.vertical]) {
              buildView(config: configModel).padding([.leading, .trailing])
            }
            if #available(macOS 14.0, *) {
              scrollView.defaultScrollAnchor(.topTrailing)
            } else {
              scrollView
            }
            footer(
              reset: {
                configModel.resetToDefault()
              },
              apply: {
                save(configModel)
              },
              close: {
                FcitxInputController.inputMethodConfigController.window?.performClose(_: nil)
              })
          }.padding([.top], 1)  // Cannot be 0 otherwise content overlaps with title bar.
        } else if let errorMsg = viewModel.errorMsg {
          Text("Cannot show config for \(selectedItem): \(errorMsg)")
        }
      } else {
        Text("Select an input method from the side bar.")
      }
    }
    .sheet(isPresented: $addGroupDialog.presented) {
      addGroupDialog.view()
    }
    .sheet(isPresented: $renameGroupDialog.presented) {
      renameGroupDialog.view()
    }
    .sheet(isPresented: $addingInputMethod) {
      VStack {
        AvailableInputMethodView(
          selection: $inputMethodsToAdd,
          addToGroup: $addToGroup,
          onDoubleClick: add
        ).padding([.leading])
        HStack {
          Button {
            addingInputMethod = false
            inputMethodsToAdd = Set()
          } label: {
            Text("Cancel")
          }

          Spacer()

          Button {
            showImportTable = true
          } label: {
            Text("Import customized table")
          }
          Button {
            add()
            addingInputMethod = false
          } label: {
            Text("Add")
          }.buttonStyle(.borderedProminent)
            .disabled(inputMethodsToAdd.isEmpty)
        }.padding()
      }.padding([.top])
        .sheet(isPresented: $showImportTable) {
          ImportTableView().load(
            onError: { msg in
              importTableErrorMsg = msg
              showImportTableError = true
            },
            finalize: {
              refresh()
            })
        }
        .toast(isPresenting: $showImportTableError) {
          AlertToast(
            displayMode: .hud,
            type: .error(Color.red), title: importTableErrorMsg)
        }
    }
  }

  private func add() {
    if let groupName = addToGroup?.name {
      viewModel.addItems(groupName, inputMethodsToAdd)
    }
    inputMethodsToAdd = Set()
  }

  private func save(_ configModel: Config) {
    if let name = viewModel.selectedIMName {
      setConfig("fcitx://config/inputmethod/\(name)", configModel.encodeValue())
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
          errorMsg = NSLocalizedString(
            "Couldn't decode input method config: not UTF-8", comment: "")
          FCITX_ERROR("Couldn't decode input method config: not UTF-8")
        }
      } catch {
        errorMsg =
          NSLocalizedString("Couldn't load input method config", comment: "") + ": \(error)"
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
        self.load()  // Refresh to avoid UI state inconsistency.
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

private func languageCodeMatch(_ code: String) -> Bool {
  guard let languageCode = Locale.current.language.languageCode?.identifier else {
    return true
  }
  // "".split throws
  return !code.isEmpty && String(code.split(separator: "_")[0]) == languageCode
}

struct AvailableInputMethodView: View {
  @Binding var selection: Set<InputMethod>
  @Binding fileprivate var addToGroup: Group?
  @StateObject private var viewModel = ViewModel()
  @State var enabledIMs = Set<String>()
  var onDoubleClick: () -> Void

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedLanguageCode) {
        ForEach(viewModel.languages(), id: \.code) { language in
          Text(language.localized)
        }
      }
      Toggle(
        NSLocalizedString("Only show current language", comment: ""),
        isOn: Binding(
          get: { viewModel.addIMOnlyShowCurrentLanguage ?? false },
          set: { viewModel.addIMOnlyShowCurrentLanguage = $0 }
        )
      )
    } detail: {
      // Input methods for this language
      if viewModel.selectedLanguageCode != nil {
        List(selection: $selection) {
          ForEach(viewModel.availableIMsForLanguage, id: \.self) { im in
            Text(im.displayName)
          }
        }.contextMenu(forSelectionType: InputMethod.self) { items in
        } primaryAction: { items in
          onDoubleClick()
          // Hack: enabledIMs isn't synced with group's inputMethods.
          enabledIMs.formUnion(items.map { $0.uniqueName })
          viewModel.refresh(enabledIMs)
        }
      } else {
        Text("Select a language from the left list.")
      }
    }
    .frame(minWidth: 640, minHeight: 480)
    .onAppear {
      enabledIMs = Set(addToGroup?.inputMethods.map { $0.name } ?? [])
      viewModel.refresh(enabledIMs)
    }
    .alert(
      NSLocalizedString("Error", comment: ""),
      isPresented: $viewModel.hasError,
      presenting: ()
    ) { _ in
      Button {
        viewModel.errorMsg = nil
      } label: {
        Text("OK")
      }.buttonStyle(.borderedProminent)
    } message: { _ in
      Text(viewModel.errorMsg!)
    }
  }

  private class ViewModel: ObservableObject {
    @AppStorage("AddIMOnlyShowCurrentLanguage") var addIMOnlyShowCurrentLanguage: Bool?
    @Published var availableIMs = [String: [InputMethod]]()
    @Published var hasError = false
    @Published var selectedLanguageCode: String? {
      didSet {
        updateList()
      }
    }
    @Published var alreadyEnabled = Set<String>() {
      didSet {
        updateList()
      }
    }
    @Published var availableIMsForLanguage: [InputMethod] = []

    var errorMsg: String? {
      didSet {
        hasError = (errorMsg != nil)
      }
    }

    private func updateList() {
      if let selectedLanguageCode = selectedLanguageCode {
        if let ims = availableIMs[selectedLanguageCode] {
          availableIMsForLanguage = ims.filter { !alreadyEnabled.contains($0.uniqueName) }
          return
        }
      }
      availableIMsForLanguage = []
    }

    func refresh(_ alreadyEnabled: Set<String>) {
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
          errorMsg =
            NSLocalizedString("Cannot parse json", comment: "") + ": \(error.localizedDescription)"
        }
      } else {
        errorMsg = NSLocalizedString("Cannot decode json string into UTF-8 data", comment: "")
      }
      self.alreadyEnabled = alreadyEnabled
    }

    fileprivate struct LocalizedLanguageCode: Comparable {
      let code: String
      let localized: String

      init(code: String) {
        self.code = code
        if code == "" {
          localized = NSLocalizedString("Unknown", comment: "")
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
        .filter { !(addIMOnlyShowCurrentLanguage ?? false) || languageCodeMatch($0) }
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
        Button {
          self.presented = false
        } label: {
          Text("Cancel")
        }
        Button {
          if let cont = self.continuation {
            cont(self.userInput)
          }
          self.presented = false
        } label: {
          Text("OK")
        }.disabled(self.userInput.isEmpty)
          .buttonStyle(.borderedProminent)
      }
    }.padding()
      .frame(minWidth: 200)
  }
}

#Preview {
  InputMethodConfigView()
}
