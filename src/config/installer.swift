import Foundation
import Logging

let mainFileName = "Fcitx5-\(arch).tar.bz2"
let mainDebugFileName = "Fcitx5-\(arch)-debug.tar.bz2"

func pluginBaseAddress(_ tag: String) -> String {
  return "https://github.com/fcitx-contrib/fcitx5-plugins/releases/download/macos-\(tag)/"
}

func getPluginFileName(_ plugin: String, native: Bool) -> String {
  return native ? "\(plugin)-\(arch).tar.bz2" : "\(plugin)-any.tar.bz2"
}

private func getAddress(_ tag: String, _ plugin: String, native: Bool) -> String {
  return pluginBaseAddress(tag) + getPluginFileName(plugin, native: native)
}

func getCacheURL(_ plugin: String, native: Bool) -> URL {
  let fileName = getPluginFileName(plugin, native: native)
  return cacheDir.appendingPathComponent(fileName)
}

func getPluginDescriptor(_ plugin: String) -> URL {
  return pluginDir.appendingPathComponent(plugin + ".json")
}

func getFilesFromDescriptor(_ descriptor: URL) -> [String] {
  guard let json = readJSON(descriptor) else {
    FCITX_WARN("Skipped invalid JSON \(descriptor.localPath())")
    return []
  }
  return json["files"].arrayValue.map { $0.stringValue }
}

func extractPlugin(_ plugin: String, native: Bool) -> Bool {
  let descriptor = getPluginDescriptor(plugin)
  let oldFiles = getFilesFromDescriptor(descriptor)

  mkdirP(libraryDir.localPath())
  let url = getCacheURL(plugin, native: native)
  let ret = exec("/usr/bin/tar", ["-xjf", url.localPath(), "-C", libraryDir.localPath()])
  let _ = removeFile(url)

  if ret {
    let newFiles = getFilesFromDescriptor(descriptor)
    let removedFiles = oldFiles.filter { !newFiles.contains($0) }
    if removedFiles.count > 0 {
      FCITX_INFO("Removing \(removedFiles) which are no longer needed")
      for file in removedFiles {
        let _ = removeFile(libraryDir.appendingPathComponent(file))
      }
    }
  }
  return ret
}

struct VersionItem: Codable {
  let tag: String
  let macos: String
  let sha: String
  let time: Int64
}

private struct Version: Codable {
  let versions: [VersionItem]
}

func checkMainUpdate(_ callback: @escaping (Bool, Bool, VersionItem?, VersionItem?) -> Void) {
  guard
    let url = URL(
      string: "\(sourceRepo)/releases/download/latest/version.json")
  else {
    return
  }
  getNoCacheSession().dataTask(with: url) { data, response, error in
    if let data = data,
      let version = try? JSONDecoder().decode(Version.self, from: data)
    {
      var latestCompatible = false
      var latest: VersionItem? = nil
      var stable: VersionItem? = nil
      for item in version.versions {
        if item.tag == "latest" {
          latestCompatible = compatibleWith(item.macos)
        }
        // Assume linear history and sorted version.json.
        // We don't backport by keeping multiple version branches.
        if item.time <= unixTime {
          break
        }
        if compatibleWith(item.macos) {
          if item.tag == "latest" {
            latest = item
          } else {
            stable = item
            break
          }
        }
      }
      callback(true, latestCompatible, latest, stable)
    } else {
      callback(false, false, nil, nil)
    }
  }.resume()
}

class Updater {
  private let tag: String
  private let main: Bool
  private let debug: Bool
  private let nativePlugins: [String]
  private let dataPlugins: [String]

  init(tag: String, main: Bool, debug: Bool, nativePlugins: [String], dataPlugins: [String]) {
    self.tag = tag
    self.main = main
    self.debug = debug
    self.nativePlugins = nativePlugins
    self.dataPlugins = dataPlugins
    if tag != "latest" && debug {
      FCITX_ERROR("Debug build only exists on latest")
    }
  }

  func update(
    onFinish: @escaping (Bool, [String: Bool], [String: Bool]) -> Void,
    onProgress: (@Sendable (Double) -> Void)? = nil
  ) {
    let mainAddress =
      "\(sourceRepo)/releases/download/\(self.tag)/\(self.debug ? mainDebugFileName : mainFileName)"
    let downloader = Downloader(
      nativePlugins.map({ getAddress(self.tag, $0, native: true) })
        + dataPlugins.map({ getAddress(self.tag, $0, native: false) }) + (main ? [mainAddress] : [])
    )
    downloader.download(
      onFinish: { [self] results in
        var nativeResults = nativePlugins.reduce(into: [String: Bool](), { $0[$1] = false })
        for plugin in nativePlugins {
          let result = results[getAddress(self.tag, plugin, native: true)]!
          let fileName = getPluginFileName(plugin, native: true)
          if result {
            if extractPlugin(plugin, native: true) {
              nativeResults[plugin] = true
              FCITX_INFO("Successfully installed \(fileName)")
            } else {
              FCITX_ERROR("Failed to extract \(fileName)")
            }
          } else {
            FCITX_ERROR("Failed to download \(fileName)")
          }
        }

        var dataResults: [String: Bool] = dataPlugins.reduce(
          into: [String: Bool](), { $0[$1] = false })
        for plugin in dataPlugins {
          let result = results[getAddress(self.tag, plugin, native: false)]!
          let fileName = getPluginFileName(plugin, native: false)
          if result {
            if extractPlugin(plugin, native: false) {
              dataResults[plugin] = true
              FCITX_INFO("Successfully installed \(fileName)")
            } else {
              FCITX_ERROR("Failed to extract \(fileName)")
            }
          } else {
            FCITX_ERROR("Failed to download \(fileName)")
          }
        }
        onFinish(results[mainAddress] ?? false, nativeResults, dataResults)
      }, onProgress: onProgress)
  }
}
