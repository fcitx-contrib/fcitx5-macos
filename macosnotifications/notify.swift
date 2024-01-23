import CxxNotify
import UserNotifications

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
        NSLog("Notification permission is granted")
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
    if actionIdent == "com.apple.UNNotificationDefaultActionIdentifier" {
      // This notification is dismissed. No need to close it manually.
      fcitx.destroyNotificationItem(externalIdent, NOTIFICATION_CLOSED_REASON_DISMISSED.rawValue)
    } else {
      // The user has initiated an action.
      fcitx.handleActionResult(externalIdent, actionIdent)
    }
    completionHandler()
  }
}

@_cdecl("sendNotificationProxy")
public func sendNotificationProxy(
  _ identifier: UnsafePointer<CChar>,
  _ iconPath: UnsafePointer<CChar>?,
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
    iconPath.flatMap { path in String(cString: path) },
    String.init(cString: title),
    String.init(cString: body),
    actionStrings,
    timeout
  )
}

public func sendNotification(
  _ identifier: String,
  _ iconPath: String?,
  _ title: String, _ body: String,
  _ actionStrings: [String],
  _ timeout: Double
) {
  DispatchQueue.main.async {
    let categoryIdent = "ACTION_CATEGORY_\(identifier)"
    var actions: [UNNotificationAction] = []
    for i in stride(from: 0, to: actionStrings.count, by: 2) {
      let action = UNNotificationAction(
        identifier: actionStrings[i],
        title: actionStrings[i + 1],
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

    if let iconPath = iconPath {
      if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: iconPath), options: nil) {
        // Add the attachment to the notification content
        content.attachments = [attachment]
      }
    }

    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

    center.add(request) { error in
      if let error = error {
        NSLog("Cannot send notification: \(error.localizedDescription)")
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        closeNotification(identifier, NOTIFICATION_CLOSED_REASON_EXPIRY.rawValue)
      }
    }
  }
}

public func closeNotification(
  _ identifier: String,
  _ reason: UInt32
) {
  DispatchQueue.main.async {
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
    fcitx.destroyNotificationItem(identifier, reason)
  }
}
