#pragma once

#include <cstdint>

// Refer to https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html
enum NotificationClosedReason {
     /// The notification expired.
     NOTIFICATION_CLOSED_REASON_EXPIRY = 1,

     /// The notification was dismissed by the user.
     NOTIFICATION_CLOSED_REASON_DISMISSED = 2,

     /// The notification was closed by a call to CloseNotification.
     NOTIFICATION_CLOSED_REASON_CLOSED = 3,

     /// Undefined/reserved reasons.
     NOTIFICATION_CLOSED_REASON_UNDEFINED = 4,
};

namespace fcitx {

void handleActionResult(const char *notificationId, const char *actionId) noexcept;

void destroyNotificationItem(const char *notificationId, uint32_t closed_reason) noexcept;

}
