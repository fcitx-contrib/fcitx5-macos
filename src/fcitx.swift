import InputMethodKit

var globalClient: Any?
var serverInstance: IMKServer?
var candidateList: [String] = []
var imkc = IMKCandidates()

public func setClient(_ client: Any) {
  globalClient = client
}

public func setServer(_ server: IMKServer) {
  serverInstance = server
}

public func setImkc(_ candidates: Any) {
  imkc = candidates as! IMKCandidates  // swiftlint:disable:this force_cast
}

public func commit(_ string: String) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
  serverInstance!.commitComposition(client)
  NSLog("commit: \(string) count=\(string.count)")
}

public func clearCandidateList() {
  candidateList.removeAll()
}

public func appendCandidate(_ candidate: String) {
  candidateList.append(candidate)
}

public func getCandidateList() -> [String] {
  return candidateList
}

public func showCandidatePanel() {
  imkc.update()
  imkc.show()
}
