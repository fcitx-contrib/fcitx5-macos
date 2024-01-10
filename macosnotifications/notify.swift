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


// This is a bridge function. Please convert all Swift types to C types. For example, convert String to accept const char *.
@_cdecl("sendNotificationProxy")
public func sendNotificationProxy(
  _ identifier: UnsafePointer<CChar>,
  _ title: UnsafePointer<CChar>,
  _ body: UnsafePointer<CChar>,
  _ cActionStrings: UnsafePointer<UnsafePointer<CChar>>?,
  _ cActionStringCount: Int,
  _ timeout: Double
) {
  var actionStrings: [String] = []
  if let cActionStrings = cActionStrings {
    for i in 0..<cActionStringCount {
      actionStrings.append(String.init(cString: cActionStrings[i]))
    }
  }
  sendNotification(
    String.init(cString: identifier),
    String.init(cString: title),
    String.init(cString: body),
    actionStrings,
    timeout
  )
}

public func sendNotification(
  _ identifier: String,
  _ title: String, _ body: String,
  _ actionStrings: [String],
  _ timeout: Double
) {
  let categoryIdent = "ACTION_CATEGORY_\(identifier)"
  var actions: [UNNotificationAction] = []
  for i in stride(from: 0, to: actionStrings.count, by: 2) {
    let action = UNNotificationAction(
      identifier: actionStrings[i],
      title: actionStrings[i+1],
      options: .foreground
    )
    actions.append(action)
  }

  let category = UNNotificationCategory(
    identifier: categoryIdent,
    actions: actions,
    intentIdentifiers: [],
    hiddenPreviewsBodyPlaceholder: "",
    options: .customDismissAction
  )
  center.setNotificationCategories([category])

  let content = UNMutableNotificationContent()
  content.title = title
  content.body = body
  content.categoryIdentifier = categoryIdent

  let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

  NSLog("send notif: \(request.content.title) \(request)")

  center.add(request) { error in
    if let error = error {
      NSLog("Cannot send notification: \(error.localizedDescription)")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
      closeNotification(identifier)
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
  center.removeDeliveredNotifications(withIdentifiers: [identifier])
  fcitx.destroyNotificationItem(identifier)
}
