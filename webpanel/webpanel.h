#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "candidate_window.hpp"
#include "webview_candidate_window.hpp"

namespace candidate_window {
FCITX_CONFIG_ENUM_NAME_WITH_I18N(theme_t, N_("System"), N_("Light"), N_("Dark"))
FCITX_CONFIG_ENUM_NAME_WITH_I18N(layout_t, N_("Horizontal"), N_("Vertical"))
} // namespace candidate_window

namespace fcitx {

struct NoSaveAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return true; }
    void dumpDescription(RawConfig &config) const {}
};

FCITX_CONFIGURATION(
    WebPanelConfig,

    OptionWithAnnotation<std::string, NoSaveAnnotation> preview{
        this, "Preview", _("Type here to preview style")};
    Option<candidate_window::theme_t> theme{this, "Theme", _("Theme"),
                                            candidate_window::theme_t::system};
    Option<candidate_window::layout_t> layout{
        this, "Layout", _("Layout"), candidate_window::layout_t::horizontal};
    Option<bool> backgroundBlur{this, "BackgroundBlur", _("Background blur"),
                                true};
    Option<int, IntConstrain> blurRadius{
        this, "BlurRadius", _("Radius of blur (px)"), 16, IntConstrain(1, 32)};
    Option<bool> shadow{this, "Shadow", _("Shadow"), true};);

enum class PanelShowFlag : int;
using PanelShowFlags = fcitx::Flags<PanelShowFlag>;

class WebPanel final : public UserInterface {
public:
    WebPanel(Instance *);
    virtual ~WebPanel() = default;

    void updateConfig();
    void reloadConfig() override;
    const Configuration *getConfig() const override { return &config_; }
    void setConfig(const RawConfig &config) override;

    Instance *instance() { return instance_; }

    bool available() override { return true; }
    void suspend() override {}
    void resume() override {}
    void update(UserInterfaceComponent component,
                InputContext *inputContext) override;

    void updateInputPanel(const Text &preedit, const Text &auxUp,
                          const Text &auxDown);

private:
    Instance *instance_;
    std::unique_ptr<candidate_window::CandidateWindow> window_;

    static const inline std::string ConfPath = "conf/webpanel.conf";
    WebPanelConfig config_;

    void showAsync(bool show);
    PanelShowFlags panelShow_;
    inline void updatePanelShowFlags(bool condition, PanelShowFlag flag) {
        if (condition)
            panelShow_ |= flag;
        else
            panelShow_ = panelShow_.unset(flag);
    }
};

class WebPanelFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new WebPanel(manager->instance());
    }
};

enum class PanelShowFlag : int {
    HasAuxUp = 1,
    HasAuxDown = 1 << 1,
    HasPreedit = 1 << 2,
    HasCandidates = 1 << 3
};

} // namespace fcitx
