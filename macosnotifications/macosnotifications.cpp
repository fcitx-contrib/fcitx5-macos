#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>

#include "../macosfrontend/macosfrontend-public.h"
#include "macosnotifications.h"

namespace fcitx {

void Notifications::updateConfig() {
    hiddenNotifications_.clear();
    for (const auto &id: config_.hiddenNotifications.value()) {
        hiddenNotifications_.insert(id);
    }
}

void Notifications::reloadConfig() {
    readAsIni(config_, ConfPath);
    updateConfig();
}

void Notifications::save() {
    std::vector<std::string> values_;
    for (const auto &id: hiddenNotifications_) {
        values_.push_back(id);
    }
    config_.hiddenNotifications.setValue(std::move(values_));
    safeSaveAsIni(config_, ConfPath);
}

uint32_t Notifications::sendNotification(
        const std::string &appName,
        uint32_t replaceId,
        const std::string &appIcon,
        const std::string &summary,
        const std::string &body,
        const std::vector<std::string> &actions,
        int32_t timeout,
        NotificationActionCallback actionCallback,
        NotificationClosedCallback closedCallback) {
    // TODO Implement
    FCITX_UNUSED(appName);
    FCITX_UNUSED(replaceId);
    FCITX_UNUSED(appIcon);
    FCITX_UNUSED(actions);
    FCITX_UNUSED(timeout);
    FCITX_UNUSED(actionCallback);
    FCITX_UNUSED(closedCallback);
    FCITX_ERROR() << "macosnotifications: send notification " << summary << ": " << body;
    macosfrontend()->call<IMacosFrontend::sendNotification>(summary, body);
    return 0;
}

void Notifications::showTip(
        const std::string &tipId,
        const std::string &appName,
        const std::string &appIcon,
        const std::string &summary,
        const std::string &body,
        int32_t timeout) {
    // TODO Implement
    FCITX_UNUSED(tipId);
    FCITX_UNUSED(appName);
    FCITX_UNUSED(appIcon);
    FCITX_UNUSED(timeout);
    FCITX_ERROR() << "macosnotifications: send tip " << summary << ": " << body;
    macosfrontend()->call<IMacosFrontend::sendNotification>(summary, body);
    return;
}

void Notifications::closeNotification(uint64_t internalId) {
    FCITX_UNUSED(internalId);
}

}

FCITX_ADDON_FACTORY(fcitx::MacosNotificationsFactory)
