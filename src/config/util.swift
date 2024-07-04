import Cocoa
import Logging
import SwiftyJSON

let homeDir = FileManager.default.homeDirectoryForCurrentUser
let libraryDir = homeDir.appendingPathComponent("Library/fcitx5")
let cacheDir = libraryDir.appendingPathComponent("cache")
let configDir = homeDir.appendingPathComponent(".config/fcitx5")
let localDir = homeDir.appendingPathComponent(".local/share/fcitx5")
let wwwDir = localDir.appendingPathComponent("www")
let imLocalDir = localDir.appendingPathComponent("inputmethod")
let pinyinLocalDir = localDir.appendingPathComponent("pinyin")
let tableLocalDir = localDir.appendingPathComponent("table")
let rimeLocalDir = localDir.appendingPathComponent("rime")

let squirrelDir = homeDir.appendingPathComponent("Library/Rime")

let sourceRepo = "https://github.com/fcitx-contrib/fcitx5-macos"

func getArch() -> String {
  #if arch(x86_64)
    return "x86_64"
  #else
    return "arm64"
  #endif
}
let arch = getArch()

func getFileNamesWithExtension(_ path: String, _ suffix: String = "", _ full: Bool = false)
  -> [String]
{
  do {
    let fileNames = try FileManager.default.contentsOfDirectory(atPath: path)
    var names: [String] = []
    for fileName in fileNames {
      if fileName.hasSuffix(suffix) {
        names.append(full ? fileName : String(fileName.prefix(fileName.count - suffix.count)))
      }
    }
    return names.sorted()
  } catch {
    return []
  }
}

extension URL {
  var isDirectory: Bool {
    (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }

  // Local file name is %-encoded with path()
  func localPath() -> String {
    let path = self.path()
    guard let decoded = path.removingPercentEncoding else {
      FCITX_ERROR("Failed to decode \(self)")
      return path
    }
    return decoded
  }

  func exists() -> Bool {
    return FileManager.default.fileExists(atPath: self.localPath())
  }

  func contains(_ file: URL) -> Bool {
    let path = self.localPath()
    let filePath = file.localPath()
    // path[-1] is always "/" for directory.
    return path.count < filePath.count && filePath.hasPrefix(path) 
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

// Caller should ensure parent directory of dest exists.
func moveAndMerge(_ src: URL, _ dest: URL) -> Bool {
  if !src.exists() {
    return false
  }
  if !dest.exists() {
    return moveFile(src, dest)
  }
  if src.isDirectory {
    if !dest.isDirectory {
      return false
    }
    do {
      var success = true
      let fileNames = try FileManager.default.contentsOfDirectory(atPath: src.localPath())
      for fileName in fileNames {
        if !moveAndMerge(
          src.appendingPathComponent(fileName), dest.appendingPathComponent(fileName))
        {
          success = false
        }
      }
      return success && removeFile(src)
    } catch {
      return false
    }
  } else {
    if dest.isDirectory {
      return false
    }
    return removeFile(dest) && moveFile(src, dest)
  }
}

func removeFile(_ file: URL) -> Bool {
  do {
    try FileManager.default.removeItem(at: file)
    return true
  } catch {
    FCITX_ERROR("Error removing \(file.localPath()): \(error.localizedDescription)")
    return false
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

func writeUTF8(_ file: URL, _ s: String) -> Bool {
  do {
    try s.write(to: file, atomically: true, encoding: .utf8)
    return true
  } catch {
    FCITX_ERROR("Error writing \(file.localPath()): \(error.localizedDescription)")
    return false
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

func openInEditor(_ path: String) {
  let apps = ["VSCodium", "Visual Studio Code"]
  for app in apps {
    let appURL = URL(fileURLWithPath: "/Applications/\(app).app")
    if appURL.exists() {
      NSWorkspace.shared.openFile(path, withApplication: app)
      return
    }
  }
  NSWorkspace.shared.openFile(path, withApplication: "TextEdit")
}

func exec(_ command: String, _ args: [String]) -> Bool {
  let process = Process()
  process.launchPath = command
  process.arguments = args

  do {
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
  } catch {
    FCITX_ERROR("Fatal error executing \(command) \(args)")
    return false
  }
}
