#ifndef _FCITX5_MACOS_MACOSNOTIFICATIONS_H_
#define _FCITX5_MACOS_MACOSNOTIFICATIONS_H_

#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx/addoninstance.h>
#include <fcitx/instance.h>
#include <fcitx-utils/i18n.h>
#include <notifications_public.h>

namespace fcitx {

FCITX_CONFIGURATION(NotificationsConfig,
                    fcitx::Option<std::vector<std::string>> hiddenNotifications{
                      this, "HiddenNotifications",
                      _("Hidden Notifications")};);

class Notifications final : public AddonInstance {
public:
  Notifications(Instance *instance) : instance_(instance) {}
  ~Notifications() = default;

  Instance *instance() { return instance_; }

  void updateConfig();
  void reloadConfig() override;
  void save() override;
  const Configuration *getConfig() const override { return &config_; }

  void setConfig(const RawConfig &config) override {
    config_.load(config, true);
    safeSaveAsIni(config_, ConfPath);
    updateConfig();
  }

  uint32_t sendNotification(const std::string &appName, uint32_t replaceId,
                            const std::string &appIcon,
                            const std::string &summary,
                            const std::string &body,
                            const std::vector<std::string> &actions,
                            int32_t timeout,
                            NotificationActionCallback actionCallback,
                            NotificationClosedCallback closedCallback);

  void showTip(const std::string &tipId, const std::string &appName,
               const std::string &appIcon, const std::string &summary,
               const std::string &body, int32_t timeout);

  void closeNotification(uint64_t internalId);

private:
  FCITX_ADDON_EXPORT_FUNCTION(Notifications, sendNotification);
  FCITX_ADDON_EXPORT_FUNCTION(Notifications, showTip);
  FCITX_ADDON_EXPORT_FUNCTION(Notifications, closeNotification);

  static const inline std::string ConfPath = "conf/macosnotifications.conf";

  NotificationsConfig config_;
  Instance *instance_;

  Flags<NotificationsCapability> capabilities_;
  std::unordered_set<std::string> hiddenNotifications_;

  int lastTipId_ = 0;
  uint32_t internalId_ = 0;
    std::unordered_map<uint32_t, std::string> internalToExternal_;
}; // class Notifications

class MacosNotificationsFactory : public AddonFactory {
  AddonInstance *create(AddonManager *manager) override {
    return new Notifications(manager->instance());
  }
};

} // namespace fcitx

#endif
