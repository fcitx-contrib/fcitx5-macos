import Foundation
import Logging

let mainFileName = "Fcitx5-\(arch).tar.bz2"
private let mainAddress = "\(sourceRepo)/releases/download/latest/\(mainFileName)"
let pluginBaseAddress =
  "https://github.com/fcitx-contrib/fcitx5-macos-plugins/releases/download/latest/"

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

private func extractPlugin(_ plugin: String, native: Bool) -> Bool {
  mkdirP(libraryDir.localPath())
  let url = getCacheURL(plugin, native: native)
  let path = url.localPath()
  let ret = exec("/usr/bin/tar", ["-xjf", path, "-C", libraryDir.localPath()])
  let _ = removeFile(url)
  return ret
}

class Updater {
  private var main: Bool
  private var nativePlugins: [String]
  private var dataPlugins: [String]

  init(main: Bool, nativePlugins: [String], dataPlugins: [String]) {
    self.main = main
    self.nativePlugins = nativePlugins
    self.dataPlugins = dataPlugins
  }

  func update(
    onFinish: @escaping (Bool, [String: Bool], [String: Bool]) -> Void,
    onProgress: ((Double) -> Void)? = nil
  ) {
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
