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

let fcitxDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("fcitx5")
private let pluginDirectory = fcitxDirectory.appendingPathComponent("plugin")
let cacheDirectory = fcitxDirectory.appendingPathComponent("cache")

struct Plugin: Identifiable, Hashable {
  let id: String
}

private let officialPlugins = [
  "chinese-addons",
  "skk",
  "hallelujah",
  "rime",
  "unikey",
  "thai",
  "lua",
].map { Plugin(id: $0) }

// fcitx5 doesn't unload addons from memory, so once loaded, we have to restart process to use an updated version.
private var inMemoryPlugins: [String] = []
private var needsRestart = false

private func getInstalledPlugins() -> [Plugin] {
  let names = getFileNamesWithExtension(pluginDirectory.localPath(), ".json")
  return names.map { Plugin(id: $0) }
}

private func getFileName(_ plugin: String) -> String {
  return plugin + "-" + arch + ".tar.bz2"
}

private func getCacheURL(_ plugin: String) -> URL {
  let fileName = getFileName(plugin)
  return cacheDirectory.appendingPathComponent(fileName)
}

private func extractPlugin(_ plugin: String) -> Bool {
  mkdirP(fcitxDirectory.localPath())
  let url = getCacheURL(plugin)
  let path = url.localPath()
  let ret = exec("/usr/bin/tar", ["-xjf", path, "-C", fcitxDirectory.localPath()])
  removeFile(url)
  return ret
}

private func getFiles(_ descriptor: URL) -> [String] {
  do {
    let content = try String(contentsOf: descriptor, encoding: .utf8)
    let data = content.data(using: .utf8, allowLossyConversion: false)!
    let json = try JSON(data: data)
    return json["files"].arrayValue.map { $0.stringValue }
  } catch {
    FCITX_WARN("Skipped invalid JSON \(descriptor.localPath())")
    return []
  }
}

private func getAutoAddIms(_ plugin: String) -> [String] {
  let descriptor = pluginDirectory.appendingPathComponent(plugin + ".json")
  do {
    let content = try String(contentsOf: descriptor, encoding: .utf8)
    let data = content.data(using: .utf8, allowLossyConversion: false)!
    let json = try JSON(data: data)
    return json["input_methods"].arrayValue.map { $0.stringValue }
  } catch {
    return []
  }
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

struct PluginView: View {
  @State private var selectedInstalled = Set<String>()
  @State private var selectedAvailable = Set<String>()
  @State private var installResults: [String: Result<Void, Error>] = [:]
  @State private var processing = false
  @State private var promptRestart = false

  @State private var observers: [NSKeyValueObservation] = []
  @State private var downloadedBytes: [Int64] = []
  @State private var totalBytes: [Int64] = []
  @State private var downloadProgress = 0.0

  @ObservedObject private var pluginVM = PluginVM()

  func refreshPlugins() {
    pluginVM.refreshPlugins()
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
        removeFile(fcitxDirectory.appendingPathComponent(file))
      }
      removeFile(descriptor)
      FCITX_INFO("Uninstalled \(selectedPlugin)")
    }
    selectedInstalled.removeAll()
    refreshPlugins()
    restartAndReconnect()
    processing = false
  }

  private func install(_ autoRestart: Bool) {
    processing = true
    mkdirP(cacheDirectory.localPath())
    let downloadGroup = DispatchGroup()
    observers.removeAll()
    downloadedBytes.removeAll()
    totalBytes.removeAll()

    for (i, selectedPlugin) in selectedAvailable.enumerated() {
      let fileName = getFileName(selectedPlugin)
      let destinationURL = getCacheURL(selectedPlugin)
      if FileManager.default.fileExists(atPath: destinationURL.localPath()) {
        FCITX_INFO("Using cached \(fileName)")
        installResults[selectedPlugin] = .success(())
        continue
      }

      guard let url = URL(string: baseURL + fileName) else { continue }
      downloadGroup.enter()
      let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
        observers[i].invalidate()
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
        downloadedBytes[i] = task.countOfBytesReceived
        totalBytes[i] = task.countOfBytesExpectedToReceive
        downloadProgress = Double(downloadedBytes.reduce(0, +)) / Double(totalBytes.reduce(0, +))
      }
      observers.append(observer)
      downloadedBytes.append(0)
      totalBytes.append(0)
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
            for im in getAutoAddIms(plugin) {
              inputMethods.append(im)
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
          ForEach(pluginVM.installedPlugins) { plugin in
            Text(plugin.id)
          }
        }
        Button("Uninstall", role: .destructive, action: uninstall).disabled(
          selectedInstalled.isEmpty || processing)
      }
      VStack {
        Text("Available").font(.system(size: sectionHeaderSize)).frame(
          maxWidth: .infinity, alignment: .leading)
        List(selection: $selectedAvailable) {
          ForEach(pluginVM.availablePlugins) { plugin in
            Text(plugin.id)
          }
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
