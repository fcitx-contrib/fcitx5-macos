import AlertToast
import Fcitx
import Logging
import SwiftUI
import SwiftyJSON
import UniformTypeIdentifiers

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
private var inMemoryPlugins = [String]()
private var needsRestart = false

private func getInstalledPlugins() -> [Plugin] {
  let names = getFileNamesWithExtension(pluginDir.localPath(), ".json")
  return names.map {
    pluginMap[$0]
      ?? Plugin(
        id: $0, category: NSLocalizedString("Other", comment: ""), native: true, github: nil)
  }
}

private func getVersion(_ plugin: String, native: Bool) -> String {
  let descriptor = getPluginDescriptor(plugin)
  guard let json = readJSON(descriptor) else {
    return ""
  }
  return native ? json["version"].stringValue : json["data_version"].stringValue
}

private func getAutoAddIms(_ plugin: String) -> [String] {
  let descriptor = getPluginDescriptor(plugin)
  guard let json = readJSON(descriptor) else {
    return []
  }
  return json["input_methods"].arrayValue.map { $0.stringValue }
}

class PluginVM: ObservableObject {
  @Published private(set) var installedPlugins = [Plugin]()
  @Published private(set) var availablePlugins = [Plugin]()
  @Published var nativeAvailable = [String]()
  @Published var dataAvailable = [String]()
  @Published var upToDate = false

  func refreshPlugins() {
    installedPlugins = getInstalledPlugins()
    availablePlugins = officialPlugins.filter { !installedPlugins.contains($0) }
    for plugin in installedPlugins.filter({ !inMemoryPlugins.contains($0.id) }) {
      inMemoryPlugins.append(plugin.id)
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

  @State private var processing = false
  @State private var promptRestart = false

  @State private var downloadProgress = 0.0

  @State private var showUpToDate = false
  @State private var showCheckFailed = false
  @State private var showDownloadFailed = false
  @State private var showUpdateAvailable = false
  @State private var showInvalidFileName = false

  @ObservedObject private var pluginVM = PluginVM()

  private let openPanel = NSOpenPanel()

  func refreshPlugins() {
    pluginVM.refreshPlugins()
  }

  private func checkUpdate() {
    processing = true
    checkPluginUpdate({ success, nativePlugins, dataPlugins in
      processing = false
      if !success {
        showCheckFailed = true
        return
      }
      pluginVM.nativeAvailable = nativePlugins
      pluginVM.dataAvailable = dataPlugins
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
    for selectedPlugin in selectedInstalled {
      let descriptor = getPluginDescriptor(selectedPlugin)
      // Plugins don't have shared files.
      // https://github.com/fcitx-contrib/fcitx5-plugins/blob/master/scripts/check-shared-files.py
      for file in getFilesFromDescriptor(descriptor) {
        let _ = removeFile(libraryDir.appendingPathComponent(file))
      }
      let _ = removeFile(descriptor)
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
              Button {
                NSWorkspace.shared.open(url)
              } label: {
                Image(systemName: "arrow.up.forward.app.fill")
              }.buttonStyle(.plain).help("\(url)")
            }
          }
        }
      }
    }
  }

  private func install(_ autoRestart: Bool, isUpdate: Bool = false) {
    processing = true

    if !isUpdate {
      pluginVM.nativeAvailable.removeAll()
      pluginVM.dataAvailable.removeAll()

      var countedPlugins = Set<String>()
      func helper(_ plugin: String) {
        if countedPlugins.contains(plugin) {
          return
        }
        countedPlugins.insert(plugin)
        // Skip installed dependencies.
        if let info = pluginMap[plugin], !pluginVM.installedPlugins.contains(info) {
          if info.native {
            pluginVM.nativeAvailable.append(plugin)
          }
          // Assumption: all official plugins contain a data tarball.
          pluginVM.dataAvailable.append(plugin)
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

    let updater = Updater(
      tag: "latest", main: false, debug: false, nativePlugins: pluginVM.nativeAvailable,
      dataPlugins: pluginVM.dataAvailable)
    updater.update(
      onFinish: { _, nativeResults, dataResults in
        processing = false
        var inputMethods = [String]()
        if !isUpdate {
          let downloadedPlugins = selectedPlugins.filter {
            (nativeResults[$0] ?? true) && (dataResults[$0] ?? true)
          }
          if downloadedPlugins.isEmpty {
            showDownloadFailed = true
            return
          }
          // Don't add IMs for dependencies.
          inputMethods = downloadedPlugins.flatMap { getAutoAddIms($0) }
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
            restart()
          } else {
            promptRestart = true
          }
        }
      },
      onProgress: { progress in
        downloadProgress = progress
      })
  }

  private func restart() {
    FcitxInputController.pluginManager.window?.performClose(_: nil)
    DispatchQueue.main.async {
      restartProcess()
    }
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

                ForEach(
                  Set(pluginVM.nativeAvailable).union(pluginVM.dataAvailable).sorted(), id: \.self
                ) {
                  plugin in
                  Text(plugin)
                }

                Spacer().frame(height: gapSize)

                Text("Fcitx5 will auto restart if needed.")

                HStack {
                  Button {
                    showUpdateAvailable = false
                  } label: {
                    Text("Cancel")
                  }
                  Button {
                    showUpdateAvailable = false
                    install(true, isUpdate: true)
                  } label: {
                    Text("Update")
                  }.buttonStyle(.borderedProminent)
                }
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
          Button {
            install(false)
          } label: {
            Text("Install")
          }.disabled(selectedAvailable.isEmpty || processing)
            .buttonStyle(.borderedProminent)
          Button {
            install(true)
          } label: {
            Text("Install silently").tooltip(
              NSLocalizedString(
                "Upgrading a plugin needs to restart IM. Click it to auto restart on demand.",
                comment: ""))
          }.disabled(selectedAvailable.isEmpty || processing)
            .buttonStyle(.borderedProminent)
          Button {
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.allowedContentTypes = [UTType.init(filenameExtension: "bz2")!]
            openPanel.directoryURL = URL(
              fileURLWithPath: homeDir.appendingPathComponent("Downloads").localPath())
            openPanel.begin { response in
              if response == .OK {
                for url in openPanel.urls {
                  let fileName = url.lastPathComponent
                  for pluginName in pluginMap.keys {
                    if fileName == getPluginFileName(pluginName, native: true) {
                      mkdirP(cacheDir.localPath())
                      let cacheFileURL = getCacheURL(pluginName, native: true)
                      let _ = copyFile(url, cacheFileURL)
                      let _ = exec(
                        "/usr/bin/xattr", ["-dr", "com.apple.quarantine", cacheFileURL.localPath()])
                      let _ = extractPlugin(pluginName, native: true)
                      restart()
                    }
                  }
                }
                showInvalidFileName = true
              }
            }
          } label: {
            Text("Install manually")
          }
        }
      }
    }.padding()
      .sheet(isPresented: $promptRestart) {
        VStack {
          Text("Please restart Fcitx5 in IM menu")
          Button {
            promptRestart = false
          } label: {
            Text("OK")
          }.buttonStyle(.borderedProminent)
        }.padding()
      }
      .toast(isPresenting: $showUpToDate) {
        AlertToast(
          displayMode: .hud,
          type: .complete(Color.green),
          title: NSLocalizedString("All plugins are up to date", comment: ""))
      }
      .toast(isPresenting: $showCheckFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Failed to check update", comment: ""))
      }
      .toast(isPresenting: $showDownloadFailed) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Download failed", comment: ""))
      }
      .toast(isPresenting: $showInvalidFileName) {
        AlertToast(
          displayMode: .hud, type: .error(Color.red),
          title: NSLocalizedString("Invalid file name", comment: ""))
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
