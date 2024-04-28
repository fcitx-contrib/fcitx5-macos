import Foundation
import Logging
import SwiftyJSON

func getFileNamesWithExtension(_ path: String, _ suffix: String) -> [String] {
  do {
    let fileNames = try FileManager.default.contentsOfDirectory(atPath: path)
    var names: [String] = []
    for fileName in fileNames {
      if fileName.hasSuffix(suffix) {
        names.append(String(fileName.prefix(fileName.count - suffix.count)))
      }
    }
    return names.sorted()
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

func copyFile(_ src: URL, _ dest: URL) -> Bool {
  do {
    try FileManager.default.copyItem(at: src, to: dest)
    return true
  } catch {
    FCITX_ERROR(
      "Error copying \(src.localPath()) to \(dest.localPath()): \(error.localizedDescription)")
    return false
  }
}

func moveFile(_ src: URL, _ dest: URL) -> Bool {
  do {
    try FileManager.default.moveItem(at: src, to: dest)
    return true
  } catch {
    FCITX_ERROR(
      "Error moving \(src.localPath()) to \(dest.localPath()): \(error.localizedDescription)")
    return false
  }
}

func removeFile(_ file: URL) {
  do {
    try FileManager.default.removeItem(at: file)
  } catch {
    FCITX_ERROR("Error removing \(file.localPath()): \(error.localizedDescription)")
  }
}

func readUTF8(_ file: URL) -> String? {
  do {
    return try String(contentsOf: file, encoding: .utf8)
  } catch {
    FCITX_ERROR("Error reading \(file.localPath()): \(error.localizedDescription)")
    return nil
  }
}

func readJSON(_ file: URL) -> JSON? {
  if let content = readUTF8(file),
    let data = content.data(using: .utf8, allowLossyConversion: false)
  {
    do {
      return try JSON(data: data)
    } catch {}
  }
  return nil
}

func exec(_ command: String, _ args: [String]) -> Bool {
  let process = Process()
  process.launchPath = command
  process.arguments = args

  process.launch()
  process.waitUntilExit()
  return process.terminationStatus == 0
}
