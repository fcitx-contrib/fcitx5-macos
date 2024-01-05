import InputMethodKit
import UserNotifications

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
  if candidateList.isEmpty {
    imkc.hide()
  } else {
    imkc.update()
    imkc.show()
  }
}

public func showPreedit(_ preedit: String, caretPos: Int) {
  guard let client = globalClient as? IMKTextInput else {
    return
  }
  client.setMarkedText(
    preedit,
    selectionRange: NSRange(location: caretPos, length: 0),
    replacementRange: NSRange(location: NSNotFound, length: 0)
  )
}

public func displayNotification(_ summary: String, _ body: String) {
  let notification = UNMutableNotificationContent()
  notification.title = summary
  notification.body = body

  let notificationRequest = UNNotificationRequest(
    identifier: UUID().uuidString, content: notification, trigger: nil)

  UNUserNotificationCenter.current().add(notificationRequest) { error in
    if let error = error {
      NSLog("Cannot send notification: \(error.localizedDescription)")
    }
  }
}
