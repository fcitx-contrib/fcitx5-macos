import SwiftFcitx
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  override init() {
    super.init()
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
      if let error = error {
        NSLog("Error requesting notification permissions: \(error.localizedDescription)")
        return
      }
      if granted {
        NSLog("swift-Notification: granted!")
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let externalIdent = response.notification.request.identifier
    let actionIdent = response.actionIdentifier
    NSLog("notifications: for \(externalIdent) there is action \(actionIdent)")
    completionHandler()
  }
}
