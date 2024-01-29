import Logging
import SwiftUI

private func getArch() -> String {
  #if arch(x86_64)
    return "x86_64"
  #else
    return "arm64"
  #endif
}
let arch = getArch()

let baseURL = "https://github.com/fcitx-contrib/fcitx5-macos-plugins/releases/download/latest/"
// let baseURL = "http://localhost:8000/" // For local debug

let errorDomain = "org.fcitx.inputmethod.Fcitx5"

let fcitxDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("fcitx5")
private let pluginDirectory = fcitxDirectory.appendingPathComponent("plugin")
private let cacheDirectory = fcitxDirectory.appendingPathComponent("cache")

struct Plugin: Identifiable, Hashable {
  let id: String
}

private let officialPlugins = [
  "chinese-addons",
  "skk",
  "hallelujah",
  "rime",
  "thai",
  "lua",
].map { Plugin(id: $0) }

private func getInstalledPlugins() -> [Plugin] {
  let suffix = ".json"
  do {
    let fileNames = try FileManager.default.contentsOfDirectory(atPath: pluginDirectory.path)
    var plugins: [Plugin] = []
    for fileName in fileNames {
      if fileName.hasSuffix(suffix) {
        plugins.append(Plugin(id: String(fileName.prefix(fileName.count - suffix.count))))
      }
    }
    return plugins
  } catch {
    return []
  }
}

private func mkdirP(_ path: String) {
  do {
    try FileManager.default.createDirectory(
      atPath: path, withIntermediateDirectories: true, attributes: nil)
  } catch {}
}

private func getFileName(_ plugin: String) -> String {
  return plugin + "-" + arch + ".tar.bz2"
}

private func getCacheURL(_ plugin: String) -> URL {
  let fileName = getFileName(plugin)
  return cacheDirectory.appendingPathComponent(fileName)
}

private func extractPlugin(_ plugin: String) -> Bool {
  mkdirP(fcitxDirectory.path())
  let path = getCacheURL(plugin).path()
  let task = Process()
  task.launchPath = "/usr/bin/tar"
  task.arguments = ["-xjf", path, "-C", fcitxDirectory.path()]
  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = pipe

  task.launch()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8) ?? "Unknown Error"

  task.waitUntilExit()
  if task.terminationStatus != 0 {
    FCITX_ERROR("Fail to extract \(path): \(output)")
    return false
  }
  return true
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
  }
}

struct PluginView: View {
  @State private var selectedAvailable = Set<String>()
  @State private var installResults: [String: Result<Void, Error>] = [:]
  @State private var processing = false

  @ObservedObject private var pluginVM = PluginVM()

  func refreshPlugins() {
    pluginVM.refreshPlugins()
  }

  private func install() {
    processing = true
    mkdirP(cacheDirectory.path())
    let downloadGroup = DispatchGroup()
    for selectedPlugin in selectedAvailable {
      let fileName = getFileName(selectedPlugin)
      let destinationURL = getCacheURL(selectedPlugin)
      if FileManager.default.fileExists(atPath: destinationURL.path()) {
        FCITX_INFO("Using cached \(fileName)")
        installResults[selectedPlugin] = .success(())
        continue
      }

      guard let url = URL(string: baseURL + fileName) else { continue }
      downloadGroup.enter()
      URLSession.shared.downloadTask(with: url) { localURL, response, error in
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
          do {
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            installResults[selectedPlugin] = .success(())
          } catch {
            installResults[selectedPlugin] = .failure(error)
          }
        }
      }.resume()
    }
    selectedAvailable.removeAll()

    downloadGroup.notify(queue: .main) {
      for (plugin, result) in installResults {
        switch result {
        case .success:
          if extractPlugin(plugin) {
            FCITX_INFO("Successful installed \(plugin)")
          } else {
            FCITX_ERROR("Failed to install \(plugin)")
          }
        case .failure(let error):
          FCITX_ERROR("Failed to download \(plugin): \(error.localizedDescription)")
        }
      }
      installResults.removeAll()
      refreshPlugins()
      processing = false
    }
  }

  var body: some View {
    HStack {
      VStack {
        Text("Installed").font(.system(size: sectionHeaderSize)).frame(
          maxWidth: .infinity, alignment: .leading)
        List {
          ForEach(pluginVM.installedPlugins) { plugin in
            Text(plugin.id)
          }
        }
      }
      VStack {
        Text("Available").font(.system(size: sectionHeaderSize)).frame(
          maxWidth: .infinity, alignment: .leading)
        List(selection: $selectedAvailable) {
          ForEach(pluginVM.availablePlugins) { plugin in
            Text(plugin.id)
          }
        }
        Button("Install", action: install).disabled(selectedAvailable.isEmpty || processing)
      }
    }.padding()
  }
}

class PluginManager: NSWindowController {
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
