import Foundation
import Logging

actor Downloader {
  private var urls = [URL]()
  private var observers = [String: NSKeyValueObservation]()
  private var downloadedBytes = [String: Int64]()
  private var totalBytes = [String: Int64]()

  init(_ addresses: [String]) {
    self.urls = addresses.compactMap { URL(string: $0) }
  }

  private func updateProgress(
    address: String, downloaded: Int64, total: Int64, observer: NSKeyValueObservation? = nil
  ) -> Double {
    downloadedBytes[address] = downloaded
    totalBytes[address] = total
    if let observer = observer {
      observers[address] = observer
    }
    let sum = self.totalBytes.values.reduce(0, +)
    return Double(self.downloadedBytes.values.reduce(0, +)) / (sum == 0 ? 0.0 : Double(sum))
  }

  func download(onProgress: (@Sendable (Double) -> Void)? = nil) async -> [String: Bool] {
    mkdirP(cacheDir.localPath())
    return await withTaskGroup(of: (String, Bool).self, returning: [String: Bool].self) { group in
      for url in urls {
        let address = url.absoluteString
        let fileName = url.lastPathComponent
        let destinationURL = cacheDir.appendingPathComponent(fileName)
        group.addTask {
          if destinationURL.exists() {
            FCITX_INFO("Using cached \(fileName)")
            return (address, true)
          }
          let (localURL, response, error) = await withCheckedContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
              continuation.resume(returning: (localURL, response, error))
            }
            if let onProgress = onProgress {
              let observer = task.progress.observe(\.fractionCompleted) { progress, _ in
                Task {
                  let ratio = await self.updateProgress(
                    address: address, downloaded: task.countOfBytesReceived,
                    total: task.countOfBytesExpectedToReceive)
                  onProgress(ratio)
                }
              }
              Task {
                await self.updateProgress(
                  address: address, downloaded: 0, total: 0, observer: observer)
              }
            }
            task.resume()
          }

          guard error == nil,
            let httpResponse = response as? HTTPURLResponse,
            let localURL = localURL,
            (200..<300).contains(httpResponse.statusCode)
          else {
            return (address, false)
          }
          return (address, moveFile(localURL, destinationURL))
        }
      }
      var results = [String: Bool]()
      for await pair in group {
        results[pair.0] = pair.1
      }
      return results
    }
  }
}
