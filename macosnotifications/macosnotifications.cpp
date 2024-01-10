#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>

#include "../macosfrontend/macosfrontend-public.h"
#include "macosnotifications.h"
#include "notify-swift.h"

namespace fcitx {

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
    const std::string &appName, // XXX
    uint32_t replaceId, // DONE
    const std::string &appIcon, // XXX
    const std::string &summary, // DONE
    const std::string &body,// DONE
    const std::vector<std::string> &actions, // TODO
    int32_t timeout, // DONE
    NotificationActionCallback actionCallback,
    NotificationClosedCallback closedCallback) {
    
    FCITX_UNUSED(appIcon);
    FCITX_UNUSED(actionCallback);
    FCITX_UNUSED(closedCallback);

    if (internalToExternal_.count(replaceId)) {
        closeNotification(replaceId);
    }
    
    // We cannot directly pass vector<string> to Swift.
    std::vector<const char *> actions_cstr{};
    for (const auto &action : actions) {
        actions_cstr.push_back(action.c_str());
    }

    internalId_++;
    std::string externalId = appName + std::to_string(internalId_);
    internalToExternal_[internalId_] = externalId;
    
    SwiftNotify::sendSimpleNotification(externalId.c_str(), summary.c_str(), body.c_str(), timeout);
    
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
    // Cannot reuse sendNotification because closeNotification is not
    // reliable.
    SwiftNotify::showTip(tipId, appName, appIcon, summary, body, double(timeout) / 1000);
}

void Notifications::closeNotification(uint64_t internalId) {
    if (!internalToExternal_.count(internalId)) {
        return;
    }
    auto externalId = internalToExternal_[internalId];
    SwiftNotify::closeNotification(externalId);
    internalToExternal_.erase(internalId);
}
    
/// Called by NotificationDelegate.userNotificationCenter when there
/// is an action result.  This function is merely a bridge to call the
/// global MacosNotifications instance, because it is impossible to
/// call C++ code directly from Swift code.
void handleActionResult(const char *externalId, const char *actionId)
{
    // TODO
    FCITX_ERROR() << "Action Result: " << externalId << " " << actionId;
}

} // namespace fcitx

FCITX_ADDON_FACTORY(fcitx::MacosNotificationsFactory)
