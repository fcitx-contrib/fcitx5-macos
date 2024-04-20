import Foundation

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

func mkdirP(_ path: String) {
  do {
    try FileManager.default.createDirectory(
      atPath: path, withIntermediateDirectories: true, attributes: nil)
  } catch {}
}
