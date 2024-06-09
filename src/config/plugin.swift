import AlertToast
import Fcitx
import Logging
import SwiftUI
import SwiftyJSON

private let pluginDirectory = libraryDir.appendingPathComponent("plugin")

struct Plugin: Identifiable, Hashable {
  let id: String
  let category: String
  let native: Bool
  let github: String?
  var dependencies: [String] = []
}

private var pluginMap = officialPlugins.reduce(into: [String: Plugin]()) { result, plugin in
  result[plugin.id] = plugin
}

// fcitx5 doesn't unload addons from memory, so once loaded, we have to restart process to use an updated version.
private var inMemoryPlugins: [String] = []
private var needsRestart = false

private func getInstalledPlugins() -> [Plugin] {
  let names = getFileNamesWithExtension(pluginDirectory.localPath(), ".json")
  return names.map {
    pluginMap[$0]
      ?? Plugin(
        id: $0, category: NSLocalizedString("Other", comment: ""), native: true, github: nil)
  }
}

private func getFiles(_ descriptor: URL) -> [String] {
  guard let json = readJSON(descriptor) else {
    FCITX_WARN("Skipped invalid JSON \(descriptor.localPath())")
    return []
  }
  return json["files"].arrayValue.map { $0.stringValue }
}

private func getVersion(_ plugin: String, native: Bool) -> String {
  let descriptor = pluginDirectory.appendingPathComponent(plugin + ".json")
  guard let json = readJSON(descriptor) else {
    return ""
  }
  return native ? json["version"].stringValue : json["data_version"].stringValue
}

private func getAutoAddIms(_ plugin: String) -> [String] {
  let descriptor = pluginDirectory.appendingPathComponent(plugin + ".json")
  guard let json = readJSON(descriptor) else {
    return []
  }
  return json["input_methods"].arrayValue.map { $0.stringValue }
}

class PluginVM: ObservableObject {
  @Published private(set) var installedPlugins: [Plugin] = []
  @Published private(set) var availablePlugins: [Plugin] = []
  @Published var upToDate = false

  func refreshPlugins() {
    installedPlugins = getInstalledPlugins()
    availablePlugins.removeAll()
    for plugin in officialPlugins {
      if !installedPlugins.contains(plugin) {
        availablePlugins.append(plugin)
      }
    }
    for plugin in installedPlugins {
      if !inMemoryPlugins.contains(plugin.id) {
        inMemoryPlugins.append(plugin.id)
      }
    }
    // Allow recheck update on reopen plugin manager.
    upToDate = false
  }
}

private struct Meta: Codable {
  struct Plugin: Codable {
    let name: String
    // swift-format-ignore: AlwaysUseLowerCamelCase
    let data_version: String
    let version: String?
  }
  let plugins: [Plugin]
}

func checkPluginUpdate(_ callback: @escaping (Bool, [String], [String]) -> Void) {
  guard let url = URL(string: pluginBaseAddress + "meta-\(arch).json") else {
    return callback(false, [], [])
  }
  URLSession.shared.dataTask(with: url) { data, response, error in
    var nativePlugins = [String]()
    var dataPlugins = [String]()
    if let data = data,
      let meta = try? JSONDecoder().decode(Meta.self, from: data)
    {
      let nativeVersionMap = meta.plugins.reduce(into: [String: String]()) { result, plugin in
        result[plugin.name] = plugin.version
      }
      let dataVersionMap = meta.plugins.reduce(into: [String: String]()) { result, plugin in
        result[plugin.name] = plugin.data_version
      }
      for plugin in getInstalledPlugins() {
        if let version = nativeVersionMap[plugin.id], version != getVersion(plugin.id, native: true)
        {
          nativePlugins.append(plugin.id)
        }
        if let dataVersion = dataVersionMap[plugin.id],
          dataVersion != getVersion(plugin.id, native: false)
        {
          dataPlugins.append(plugin.id)
        }
      }
      callback(true, nativePlugins, dataPlugins)
    } else {
      callback(false, [], [])
    }
  }.resume()
}

struct PluginView: View {
  @State private var selectedInstalled = Set<String>()
  @State private var selectedAvailable = Set<String>()

  @State private var nativeAvailable = [String]()
  @State private var dataAvailable = [String]()

  @State private var processing = false
  @State private var promptRestart = false

  @State private var downloadProgress = 0.0

  @State private var showUpToDate = false
  @State private var showUpdateAvailable = false

  @ObservedObject private var pluginVM = PluginVM()

  func refreshPlugins() {
    pluginVM.refreshPlugins()
  }

  private func checkUpdate() {
    processing = true
    checkPluginUpdate({ success, nativePlugins, dataPlugins in
      nativeAvailable = nativePlugins
      dataAvailable = dataPlugins
      // TODO: check success and show toast; convert up to date to a toast
      if nativePlugins.isEmpty && dataPlugins.isEmpty {
        pluginVM.upToDate = true
        showUpToDate = true
      } else {
        showUpdateAvailable = true
      }
      processing = false
    })
  }

  private func uninstall() {
    processing = true
    var keptFiles = Set<String>()
    for plugin in pluginVM.installedPlugins {
      if selectedInstalled.contains(plugin.id) {
        continue
      }
      let descriptor = pluginDirectory.appendingPathComponent(plugin.id + ".json")
      keptFiles.formUnion(getFiles(descriptor))
    }
    for selectedPlugin in selectedInstalled {
      let descriptor = pluginDirectory.appendingPathComponent(selectedPlugin + ".json")
      let files = getFiles(descriptor)
      for file in files {
        // Don't remove files shared by other plugins
        if keptFiles.contains(file) {
          continue
        }
        removeFile(libraryDir.appendingPathComponent(file))
      }
      removeFile(descriptor)
      FCITX_INFO("Uninstalled \(selectedPlugin)")
    }
    selectedInstalled.removeAll()
    refreshPlugins()
    restartAndReconnect()
    processing = false
  }

  private func categorizePlugins(_ plugins: [Plugin]) -> some View {
    let categorizedPlugins = plugins.reduce(into: [String: [Plugin]]()) { result, plugin in
      result[plugin.category, default: []].append(plugin)
    }
    return ForEach(categorizedPlugins.keys.sorted(), id: \.self) { category in
      Section(header: Text(category)) {
        ForEach(categorizedPlugins[category]!) { plugin in
          HStack {
            Text(plugin.id)
            if plugin.github != nil,
              let url = URL(string: "https://github.com/\(plugin.github!)")
            {
              Button(
                action: {
                  NSWorkspace.shared.open(url)
                },
                label: {
                  Image(systemName: "arrow.up.forward.app.fill")
                }
              ).buttonStyle(.plain).help("\(url)")
            }
          }
        }
      }
    }
  }

  private func install(_ autoRestart: Bool, isUpdate: Bool = false) {
    processing = true

    if !isUpdate {
      nativeAvailable.removeAll()
      dataAvailable.removeAll()

      var countedPlugins = Set<String>()
      func helper(_ plugin: String) {
        if countedPlugins.contains(plugin) {
          return
        }
        countedPlugins.insert(plugin)
        // Skip installed dependencies.
        if let info = pluginMap[plugin], !pluginVM.installedPlugins.contains(info) {
          if info.native {
            nativeAvailable.append(plugin)
          }
          // Assumption: all official plugins contain a data tarball.
          dataAvailable.append(plugin)
          for dependency in info.dependencies {
            helper(dependency)
          }
        }
      }
      for plugin in selectedAvailable {
        helper(plugin)
      }
    }
    let selectedPlugins = selectedAvailable
    selectedAvailable.removeAll()

    let updater = Updater(main: false, nativePlugins: nativeAvailable, dataPlugins: dataAvailable)
    updater.update(
      onFinish: { _, nativeResults, dataResults in
        var inputMethods: [String] = [String]()
        if !isUpdate {
          // Don't add IMs for dependencies.
          for plugin in selectedPlugins {
            if (nativeResults[plugin] ?? true) && (dataResults[plugin] ?? true) {
              for im in getAutoAddIms(plugin) {
                inputMethods.append(im)
              }
            }
          }
        }
        if !Set(nativeResults.filter({ _, success in success }).keys).intersection(inMemoryPlugins)
          .isEmpty
        {
          needsRestart = true
        }
        refreshPlugins()
        restartAndReconnect()
        if Fcitx.imGroupCount() == 1 {
          // Otherwise user knows how to play with it, don't mess it up.
          for im in inputMethods {
            Fcitx.imAddToCurrentGroup(im)
          }
        }
        processing = false
        if needsRestart {
          if autoRestart {
            FcitxInputController.pluginManager.window?.performClose(_: nil)
            DispatchQueue.main.async {
              restartProcess()
            }
          } else {
            promptRestart = true
          }
        }
      },
      onProgress: { progress in
        downloadProgress = progress
      })
  }

  var body: some View {
    if processing {
      ProgressView(value: downloadProgress, total: 1)
    }
    HStack {
      VStack {
        Text("Installed").font(.system(size: sectionHeaderSize)).frame(
          maxWidth: .infinity, alignment: .leading)
        List(selection: $selectedInstalled) {
          categorizePlugins(pluginVM.installedPlugins)
        }
        HStack {
          Button {
            checkUpdate()
          } label: {
            Text("Check update")
          }.buttonStyle(.borderedProminent)
            .disabled(processing || pluginVM.upToDate)
            .sheet(isPresented: $showUpdateAvailable) {
              VStack {
                Text("Update available")

                Spacer().frame(height: gapSize)

                ForEach(Set(nativeAvailable).union(dataAvailable).sorted(), id: \.self) {
                  plugin in
                  Text(plugin)
                }

                Spacer().frame(height: gapSize)

                Text("Fcitx5 will auto restart if needed.")

                Button {
                  showUpdateAvailable = false
                  install(true, isUpdate: true)
                } label: {
                  Text("Update")
                }.buttonStyle(.borderedProminent)
              }.padding()
            }
          Button("Uninstall", role: .destructive, action: uninstall).disabled(
            selectedInstalled.isEmpty || processing)
        }
      }
      VStack {
        Text("Available").font(.system(size: sectionHeaderSize)).frame(
          maxWidth: .infinity, alignment: .leading)
        List(selection: $selectedAvailable) {
          categorizePlugins(pluginVM.availablePlugins)
        }.contextMenu(forSelectionType: String.self) { items in
        } primaryAction: { items in
          // Double click
          install(false)
        }
        HStack {
          Button(
            action: {
              install(false)
            },
            label: {
              Text("Install")
            }
          ).disabled(selectedAvailable.isEmpty || processing)
            .buttonStyle(.borderedProminent)
          Button(
            action: {
              install(true)
            },
            label: {
              Text("Install silently").tooltip(
                NSLocalizedString(
                  "Upgrading a plugin needs to restart IM. Click it to auto restart on demand.",
                  comment: ""))
            }
          ).disabled(selectedAvailable.isEmpty || processing)
            .buttonStyle(.borderedProminent)
        }
      }
    }.padding()
      .sheet(isPresented: $promptRestart) {
        VStack {
          Text("Please restart Fcitx5 in IM menu")
          Button(
            action: {
              promptRestart = false
            },
            label: {
              Text("OK")
            }
          ).buttonStyle(.borderedProminent)
        }.padding()
      }
      .toast(isPresenting: $showUpToDate) {
        AlertToast(
          displayMode: .hud,
          type: .complete(Color.green),
          title: NSLocalizedString("All plugins are up to date", comment: ""))
      }
  }
}

class PluginManager: ConfigWindowController {
  let view = PluginView()
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: styleMask,
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Plugin Manager", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }

  func refreshPlugins() {
    view.refreshPlugins()
  }
}
