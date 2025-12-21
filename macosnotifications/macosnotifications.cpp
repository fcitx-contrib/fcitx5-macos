#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>

#include "fcitx.h"
#include "macosnotifications.h"

namespace fcitx {

Notifications::Notifications(Instance *instance)
    : instance_(instance),
      iconTheme_(std::make_unique<fcitx::IconTheme>("hicolor")) {
    reloadConfig();
}

void Notifications::updateConfig() {
    hiddenNotifications_.clear();
    for (const auto &id : config_.hiddenNotifications.value()) {
        hiddenNotifications_.insert(id);
    }
}

void Notifications::reloadConfig() {
    readAsIni(config_, ConfPath);
    updateConfig();
}

void Notifications::save() {
    std::vector<std::string> values_;
    for (const auto &id : hiddenNotifications_) {
        values_.push_back(id);
    }
    config_.hiddenNotifications.setValue(std::move(values_));
    safeSaveAsIni(config_, ConfPath);
}

uint32_t Notifications::sendNotification(
    const std::string &appName, uint32_t replaceId, const std::string &appIcon,
    const std::string &summary, const std::string &body,
    const std::vector<std::string> &actions, int32_t timeout,
    NotificationActionCallback actionCallback,
    NotificationClosedCallback closedCallback) {

    if (itemTable_.find(replaceId)) {
        closeNotification(replaceId);
    }

    if (timeout < 0) {
        timeout = 60 * 1000; // 1 minute
    }

    // Record a notification item to store callbacks.
    auto internalId = ++internalId_;
    auto externalId = std::format("{}-{}", appName, internalId_);
    NotificationItem item{externalId, internalId, actionCallback,
                          closedCallback};
    itemTable_.insert(item);

    // Find appIcon file.
    auto iconPath = iconTheme_->findIconPath(appIcon, 48, 1, {".png"});

    // Send the notification.
    auto actionsArray = swift::Array<swift::String>::init();
    for (const auto &action : actions) {
        actionsArray.append(action);
    }
    SwiftNotify::sendNotification(externalId.c_str(), iconPath.c_str(),
                                  summary.c_str(), body.c_str(), actionsArray,
                                  timeout);

    return internalId_;
}

void Notifications::showTip(const std::string &tipId,
                            const std::string &appName,
                            const std::string &appIcon,
                            const std::string &summary, const std::string &body,
                            int32_t timeout) {
    if (hiddenNotifications_.count(tipId)) {
        return;
    }
    std::vector<std::string> actions = {
        "dont-show", translateDomain("fcitx5", "Do not show again")};
    lastTipId_ = sendNotification(
        appName, lastTipId_, appIcon, summary, body, actions, timeout,
        [this, tipId](const std::string &action) {
            if (action == "dont-show") {
                FCITX_DEBUG() << "Dont show clicked: " << tipId;
                if (hiddenNotifications_.insert(tipId).second) {
                    save();
                }
            }
        },
        {});
}

void Notifications::closeNotification(uint64_t internalId) {
    if (auto item = itemTable_.remove(internalId)) {
        SwiftNotify::closeNotification(item->externalId,
                                       NOTIFICATION_CLOSED_REASON_CLOSED);
        // This function will call back to destroyNotificationItem, so
        // closedCallback will be called.
    }
}

/// Called by NotificationDelegate.userNotificationCenter when there
/// is an action result.  This function is merely a bridge to call the
/// global MacosNotifications instance, because it is impossible to
/// call C++ code directly from Swift code.
void handleActionResult(const char *externalId, const char *actionId) noexcept {
    with_fcitx([=](Fcitx &fcitx) {
        auto that = dynamic_cast<Notifications *>(fcitx.addon("notifications"));
        if (auto item = that->itemTable_.find(externalId)) {
            if (item->actionCallback) {
                item->actionCallback(actionId);
            }
        }
    });
}

/// Called by NotificationDelegate.closeNotification to release the
/// notification item.
void destroyNotificationItem(const char *externalId,
                             uint32_t closedReason) noexcept {
    with_fcitx([=](Fcitx &fcitx) {
        auto that = dynamic_cast<Notifications *>(fcitx.addon("notifications"));
        auto item = that->itemTable_.remove(externalId);
        if (item && item->closedCallback) {
            item->closedCallback(closedReason);
        }
    });
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(notifications, fcitx::MacosNotificationsFactory);
