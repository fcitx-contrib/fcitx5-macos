import InputMethodKit

var globalClient: Any?
var candidateList: [String] = []
var imkc = IMKCandidates()

public func setClient(_ client: Any) {
  globalClient = client
}

public func setImkc(_ candidates: Any) {
  imkc = candidates as! IMKCandidates  // swiftlint:disable:this force_cast
}

public func commit(_ string: String) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
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
  DispatchQueue.main.async {
    if candidateList.isEmpty {
      imkc.hide()
    } else {
      imkc.update()
      imkc.show()
    }
  }
}

public func showPreedit(_ preedit: String, _ caretPosUtf8: Int) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  // The caretPos argument is specified in UTF-8 bytes.
  // Convert it to UTF-16.
  var u8pos = 0
  var u16pos = 0
  for ch in preedit {
    if u8pos == caretPosUtf8 {
      break
    }
    u8pos += ch.utf8.count
    u16pos += 1
  }
  client.setMarkedText(
    NSMutableAttributedString(string: preedit),
    selectionRange: NSRange(location: u16pos, length: 0),
    replacementRange: NSRange(location: NSNotFound, length: 0)
  )
}
