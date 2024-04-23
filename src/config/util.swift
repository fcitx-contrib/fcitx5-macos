import Foundation
import Logging

func getFileNamesWithExtension(_ path: String, _ suffix: String) -> [String] {
  do {
    let fileNames = try FileManager.default.contentsOfDirectory(atPath: path)
    var names: [String] = []
    for fileName in fileNames {
      if fileName.hasSuffix(suffix) {
        names.append(String(fileName.prefix(fileName.count - suffix.count)))
      }
    }
    return names
  } catch {
    return []
  }
}

extension URL {
  // Local file name is %-encoded with path()
  func localPath() -> String {
    let path = self.path()
    guard let decoded = path.removingPercentEncoding else {
      FCITX_ERROR("Failed to decode \(self)")
      return path
    }
    return decoded
  }
}

func mkdirP(_ path: String) {
  do {
    try FileManager.default.createDirectory(
      atPath: path, withIntermediateDirectories: true, attributes: nil)
  } catch {}
}

func removeFile(_ file: URL) {
  do {
    try FileManager.default.removeItem(at: file)
  } catch {
    FCITX_ERROR("Error removing \(file.localPath()): \(error.localizedDescription)")
  }
}

func exec(_ command: String, _ args: [String]) -> Bool {
  let process = Process()
  process.launchPath = command
  process.arguments = args

  process.launch()
  process.waitUntilExit()
  return process.terminationStatus == 0
}
