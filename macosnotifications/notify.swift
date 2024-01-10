import UserNotifications
import CxxNotify

/// The notification center of the current app.
let center = UNUserNotificationCenter.current()

public class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  public override init() {
    super.init()
    center.delegate = self
  }

  public func requestAuthorization() {
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
      if let error = error {
        NSLog("Error requesting notification permissions: \(error.localizedDescription)")
        return
      }
      if granted {
        NSLog("Notification permitted")
      }
    }
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let externalIdent = response.notification.request.identifier
    let actionIdent = response.actionIdentifier
    NSLog("notifications: for \(externalIdent) there is action \(actionIdent)")
    fcitx.handleActionResult(externalIdent, actionIdent)
    completionHandler()
  }
}

public func sendSimpleNotification(
  _ identifier: String, _ title: String, _ body: String,
  _ timeout: Int32
) {
  let notif = UNMutableNotificationContent()
  notif.title = title
  notif.body = body

  let timeInterval = TimeInterval(Double(timeout) / 1000)
  let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
  
  let req = UNNotificationRequest(
    identifier: identifier, content: notif, trigger: trigger
  )

  // complete this function by implementing timeout

  center.add(req) { error in
    if let error = error {
      NSLog("Cannot send notification: \(error.localizedDescription)")
    }
  }
}

public func sendNotification(
  identifier: String,
  _ title: String, _ body: String,
  actions: [String]
) {
  let notif = UNMutableNotificationContent()
  notif.title = title
  notif.body = body

  // let categoryIdent = "ACTION_CATEGORY_\(identifier)"
  // notif.categoryIdentifier = categoryIdent

  // var notificationActions: [UNNotificationAction] = []
  // for i in stride(from: 0, to: actions.count, by: 2) {
  //   let action = UNNotificationAction(
  //     identifier: actions[i+1],
  //     title: actions[i],
  //     options: .foreground
  //   )
  //   notificationActions.append(action)
  // }

  // let category = UNNotificationCategory(
  //   identifier: categoryIdent,
  //   actions: notificationActions,
  //   intentIdentifiers: [],
  //   hiddenPreviewsBodyPlaceholder: "",
  //   options: .customDismissAction
  // )

  // center.setNotificationCategories([category])
  
  let req = UNNotificationRequest(
    identifier: identifier, content: notif, trigger: nil
  )

  center.add(req) { error in
    if let error = error {
      NSLog("Cannot send notification: \(error.localizedDescription)")
    }
  }
}

public func showTip(
  _ tipId: String, _ appName: String, _ appIcon: String, _ summary: String, _ body: String, _ timeout: Double
) {
  let categoryIdent = "ACTION_CATEGORY_\(tipId)"
  let actions = [UNNotificationAction(
                   identifier: "dont-show",
                   title: "Don't show again",
                   options: .foreground
                 )]
  let category = UNNotificationCategory(
    identifier: categoryIdent,
    actions: actions,
    intentIdentifiers: [],
    hiddenPreviewsBodyPlaceholder: "",
    options: .customDismissAction
  )
  center.setNotificationCategories([category])

  let content = UNMutableNotificationContent()
  content.title = summary
  content.body = body
  content.userInfo = ["appIcon": appIcon]
  content.categoryIdentifier = categoryIdent

  let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeout), repeats: false)

  let request = UNNotificationRequest(identifier: tipId, content: content, trigger: trigger)
  
  center.add(request) { (error) in
    if let error = error {
      NSLog("notify: failed to showTip: \(error.localizedDescription)")
    }
  }
}

public func closeNotification(
  _ identifier: String
) {
  let center = UNUserNotificationCenter.current()
  center.removeDeliveredNotifications(withIdentifiers: [identifier])
}

