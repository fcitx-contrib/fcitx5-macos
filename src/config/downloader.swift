import Foundation
import Logging

class Downloader {
  private var urls = [URL]()
  private var results = [String: Bool]()
  private var observers = [String: NSKeyValueObservation]()
  private var downloadedBytes = [String: Int64]()
  private var totalBytes = [String: Int64]()

  init(_ addresses: [String]) {
    for address in addresses {
      if let url = URL(string: address) {
        self.urls.append(url)
      }
    }
  }

  func download(onFinish: @escaping ([String: Bool]) -> Void, onProgress: ((Double) -> Void)? = nil)
  {
    mkdirP(cacheDir.localPath())
    let downloadGroup = DispatchGroup()
    for url in urls {
      let address = url.absoluteString
      let fileName = url.lastPathComponent
      let destinationURL = cacheDir.appendingPathComponent(fileName)
      if destinationURL.exists() {
        FCITX_INFO("Using cached \(fileName)")
        results[address] = true
        continue
      }

      downloadGroup.enter()
      let task = URLSession.shared.downloadTask(with: url) { [self] localURL, response, error in
        defer { downloadGroup.leave() }
        if error != nil {
          results[address] = false
          return
        }
        guard let httpResponse = response as? HTTPURLResponse,
          let localURL = localURL
        else {
          results[address] = false
          return
        }
        if !(200..<300).contains(httpResponse.statusCode) {
          results[address] = false
          return
        }
        results[address] = moveFile(localURL, destinationURL)
      }

      if let onProgress = onProgress {
        let observer = task.progress.observe(\.fractionCompleted) { [self] progress, _ in
          downloadedBytes[address] = task.countOfBytesReceived
          totalBytes[address] = task.countOfBytesExpectedToReceive
          let sum = totalBytes.values.reduce(0, +)
          onProgress(Double(downloadedBytes.values.reduce(0, +)) / (sum == 0 ? 1.0 : Double(sum)))
        }
        observers[address] = observer
        downloadedBytes[address] = 0
        totalBytes[address] = 0
      }

      task.resume()
    }

    downloadGroup.notify(queue: .main) { [self] in
      onFinish(results)
    }
  }
}
