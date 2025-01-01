import Foundation
import Logging

let mainFileName = "Fcitx5-\(arch).tar.bz2"
let mainDebugFileName = "Fcitx5-\(arch)-debug.tar.bz2"
let pluginBaseAddress =
  "https://github.com/fcitx-contrib/fcitx5-plugins/releases/download/macos/"

private func getFileName(_ plugin: String, native: Bool) -> String {
  return native ? "\(plugin)-\(arch).tar.bz2" : "\(plugin)-any.tar.bz2"
}

private func getAddress(_ plugin: String, native: Bool) -> String {
  return pluginBaseAddress + getFileName(plugin, native: native)
}

private func getCacheURL(_ plugin: String, native: Bool) -> URL {
  let fileName = getFileName(plugin, native: native)
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

private func extractPlugin(_ plugin: String, native: Bool) -> Bool {
  let descriptor = getPluginDescriptor(plugin)
  let oldFiles = getFilesFromDescriptor(descriptor)

  mkdirP(libraryDir.localPath())
  let url = getCacheURL(plugin, native: native)
  let path = url.localPath()
  let ret = exec("/usr/bin/tar", ["-xjf", path, "-C", libraryDir.localPath()])
  let _ = removeFile(url)

  if ret {
    let newFiles = getFilesFromDescriptor(descriptor)
    let removedFiles = oldFiles.filter { !newFiles.contains($0) }
    if removedFiles.count > 0 {
      FCITX_INFO("Removing \(removedFiles) which are no longer needed")
      for file in removedFiles {
        let path = libraryDir.appendingPathComponent(file)
        let _ = removeFile(path)
      }
    }
  }
  return ret
}

class Updater {
  private let main: Bool
  private let debug: Bool
  private let nativePlugins: [String]
  private let dataPlugins: [String]

  init(main: Bool, debug: Bool, nativePlugins: [String], dataPlugins: [String]) {
    self.main = main
    self.debug = debug
    self.nativePlugins = nativePlugins
    self.dataPlugins = dataPlugins
  }

  func update(
    onFinish: @escaping (Bool, [String: Bool], [String: Bool]) -> Void,
    onProgress: ((Double) -> Void)? = nil
  ) {
    let mainAddress =
      "\(sourceRepo)/releases/download/latest/\(self.debug ? mainDebugFileName : mainFileName)"
    let downloader = Downloader(
      nativePlugins.map({ getAddress($0, native: true) })
        + dataPlugins.map({ getAddress($0, native: false) }) + (main ? [mainAddress] : [])
    )
    downloader.download(
      onFinish: { [self] results in
        var nativeResults = nativePlugins.reduce(into: [String: Bool](), { $0[$1] = false })
        for plugin in nativePlugins {
          let result = results[getAddress(plugin, native: true)]!
          let fileName = getFileName(plugin, native: true)
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
          let result = results[getAddress(plugin, native: false)]!
          let fileName = getFileName(plugin, native: false)
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
