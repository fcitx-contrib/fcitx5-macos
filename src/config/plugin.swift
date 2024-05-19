import Fcitx
import Logging
import SwiftUI
import SwiftyJSON

func getArch() -> String {
  #if arch(x86_64)
    return "x86_64"
  #else
    return "arm64"
  #endif
}
let arch = getArch()

let baseURL = "https://github.com/fcitx-contrib/fcitx5-macos-plugins/releases/download/latest/"
// let baseURL = "http://localhost:8080/" // For local debug with nginx

let errorDomain = "org.fcitx.inputmethod.Fcitx5"

private let pluginDirectory = libraryDir.appendingPathComponent("plugin")

struct Plugin: Identifiable, Hashable {
  let id: String
  let category: String
  let github: String?
}

private let officialPlugins = [
  Plugin(
    id: "anthy", category: NSLocalizedString("Japanese", comment: ""), github: "fcitx/fcitx5-anthy"),
  Plugin(
    id: "chinese-addons", category: NSLocalizedString("Chinese", comment: ""),
    github: "fcitx/fcitx5-chinese-addons"),
  Plugin(
    id: "skk", category: NSLocalizedString("Japanese", comment: ""), github: "fcitx/fcitx5-skk"),
  Plugin(
    id: "hallelujah", category: NSLocalizedString("English", comment: ""),
    github: "fcitx-contrib/fcitx5-hallelujah"),
  Plugin(
    id: "rime", category: NSLocalizedString("Generic", comment: ""), github: "fcitx/fcitx5-rime"),
  Plugin(
    id: "unikey", category: NSLocalizedString("Vietnamese", comment: ""),
    github: "fcitx/fcitx5-unikey"),
  Plugin(
    id: "thai", category: NSLocalizedString("Thai", comment: ""), github: "fcitx/fcitx5-libthai"),
  Plugin(id: "lua", category: NSLocalizedString("Other", comment: ""), github: "fcitx/fcitx5-lua"),
]

private var pluginMap = officialPlugins.reduce(into: [String: Plugin]()) { result, plugin in
  result[plugin.id] = plugin
}

// fcitx5 doesn't unload addons from memory, so once loaded, we have to restart process to use an updated version.
private var inMemoryPlugins: [String] = []
private var needsRestart = false

private func getInstalledPlugins() -> [Plugin] {
  let names = getFileNamesWithExtension(pluginDirectory.localPath(), ".json")
  return names.map {
    pluginMap[$0] ?? Plugin(id: $0, category: NSLocalizedString("Other", comment: ""), github: nil)
  }
}

private func getFileName(_ plugin: String) -> String {
  return plugin + "-" + arch + ".tar.bz2"
}

private func getCacheURL(_ plugin: String) -> URL {
  let fileName = getFileName(plugin)
  return cacheDir.appendingPathComponent(fileName)
}

private func extractPlugin(_ plugin: String) -> Bool {
  mkdirP(libraryDir.localPath())
  let url = getCacheURL(plugin)
  let path = url.localPath()
  let ret = exec("/usr/bin/tar", ["-xjf", path, "-C", libraryDir.localPath()])
  removeFile(url)
  return ret
}

private func getFiles(_ descriptor: URL) -> [String] {
  guard let json = readJSON(descriptor) else {
    FCITX_WARN("Skipped invalid JSON \(descriptor.localPath())")
    return []
  }
  return json["files"].arrayValue.map { $0.stringValue }
}

private func getVersion(_ plugin: String) -> String {
  let descriptor = pluginDirectory.appendingPathComponent(plugin + ".json")
  guard let json = readJSON(descriptor) else {
    return ""
  }
  return json["version"].stringValue
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
  }
}

private struct Meta: Codable {
  struct Plugin: Codable {
    let name: String
    let version: String
  }
  let plugins: [Plugin]
}

func checkPluginUpdate(_ callback: @escaping ([String]) -> Void) {
  guard let url = URL(string: baseURL + "meta-\(arch).json") else {
    return callback([])
  }
  URLSession.shared.dataTask(with: url) { data, response, error in
    var plugins = [String]()
    if let data = data,
      let meta = try? JSONDecoder().decode(Meta.self, from: data)
    {
      let pluginVersionMap = meta.plugins.reduce(into: [String: String]()) { result, plugin in
        result[plugin.name] = plugin.version
      }
      for plugin in getInstalledPlugins() {
        if let version = pluginVersionMap[plugin.id], version != getVersion(plugin.id) {
          plugins.append(plugin.id)
        }
      }
    }
    callback(plugins)
  }.resume()
}

struct PluginView: View {
  @State private var selectedInstalled = Set<String>()
  @State private var selectedAvailable = Set<String>()
  @State private var installResults: [String: Result<Void, Error>] = [:]
  @State private var processing = false
  @State private var promptRestart = false

  @State private var observers = [String: NSKeyValueObservation]()
  @State private var downloadedBytes = [String: Int64]()
  @State private var totalBytes = [String: Int64]()
  @State private var downloadProgress = 0.0

  @State private var showUpToDate = false
  @State private var showUpdateAvailable = false

  @ObservedObject private var pluginVM = PluginVM()

  func refreshPlugins() {
    pluginVM.refreshPlugins()
  }

  private func checkUpdate() {
    checkPluginUpdate({ plugins in
      if plugins.isEmpty {
        showUpToDate = true
      } else {
        selectedAvailable = Set(plugins)
        showUpdateAvailable = true
      }
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

  private func install(_ autoRestart: Bool, autoAdd: Bool = true) {
    processing = true
    mkdirP(cacheDir.localPath())
    let downloadGroup = DispatchGroup()
    observers.removeAll()
    downloadedBytes.removeAll()
    totalBytes.removeAll()

    for selectedPlugin in selectedAvailable {
      let fileName = getFileName(selectedPlugin)
      let destinationURL = getCacheURL(selectedPlugin)
      if destinationURL.exists() {
        FCITX_INFO("Using cached \(fileName)")
        installResults[selectedPlugin] = .success(())
        continue
      }

      guard let url = URL(string: baseURL + fileName) else { continue }
      downloadGroup.enter()
      let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
        observers[selectedPlugin]?.invalidate()
        defer { downloadGroup.leave() }

        if let error = error {
          installResults[selectedPlugin] = .failure(error)
          return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
          installResults[selectedPlugin] = .failure(
            NSError(domain: errorDomain, code: 0, userInfo: nil))
          return
        }
        if !(200..<300).contains(httpResponse.statusCode) {
          installResults[selectedPlugin] = .failure(
            NSError(
              domain: errorDomain, code: httpResponse.statusCode, userInfo: nil))
          return
        }

        if let localURL = localURL {
          installResults[selectedPlugin] =
            moveFile(localURL, destinationURL)
            ? .success(()) : .failure(NSError(domain: errorDomain, code: 0, userInfo: nil))
        }
      }
      let observer = task.progress.observe(\.fractionCompleted) { progress, _ in
        downloadedBytes[selectedPlugin] = task.countOfBytesReceived
        totalBytes[selectedPlugin] = task.countOfBytesExpectedToReceive
        downloadProgress =
          Double(downloadedBytes.values.reduce(0, +)) / Double(totalBytes.values.reduce(0, +))
      }
      observers[selectedPlugin] = observer
      downloadedBytes[selectedPlugin] = 0
      totalBytes[selectedPlugin] = 0
      task.resume()
    }
    selectedAvailable.removeAll()

    downloadGroup.notify(queue: .main) {
      var inputMethods: [String] = []
      for (plugin, result) in installResults {
        switch result {
        case .success:
          if extractPlugin(plugin) {
            FCITX_INFO("Successful installed \(plugin)")
            if autoAdd {
              for im in getAutoAddIms(plugin) {
                inputMethods.append(im)
              }
            }
            if inMemoryPlugins.contains(plugin) {
              needsRestart = true
            }
          } else {
            FCITX_ERROR("Failed to install \(plugin)")
          }
        case .failure(let error):
          FCITX_ERROR("Failed to download \(plugin): \(error.localizedDescription)")
        }
      }
      installResults.removeAll()
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
            .disabled(processing)
            .sheet(isPresented: $showUpToDate) {
              VStack {
                Text("All plugins are up to date")
                Button {
                  showUpToDate = false
                } label: {
                  Text("OK")
                }.buttonStyle(.borderedProminent)
              }.padding()
            }.sheet(isPresented: $showUpdateAvailable) {
              VStack {
                Text("Update available")

                Spacer().frame(height: gapSize)

                ForEach(selectedAvailable.sorted(), id: \.self) { plugin in
                  Text(plugin)
                }

                Spacer().frame(height: gapSize)

                Text("Fcitx5 will auto restart.")

                Button {
                  showUpdateAvailable = false
                  install(true, autoAdd: false)
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
  }
}

class PluginManager: ConfigWindowController {
  let view = PluginView()
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.titled, .closable],
      backing: .buffered, defer: false)
    window.title = "Plugin Manager"
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
  }

  func refreshPlugins() {
    view.refreshPlugins()
  }
}
