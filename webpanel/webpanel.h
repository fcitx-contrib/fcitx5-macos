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

#define BORDER_WIDTH_MAX 10

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
    LightModeConfig, Option<bool> overrideDefault{this, "OverrideDefault",
                                                  _("Override default"), false};
    Option<Color> highlightColor{this, "HighlightColor", "Highlight color",
                                 Color(0, 0, 255, 255)};
    Option<Color> panelColor{this, "PanelColor", "Panel color",
                             Color(255, 255, 255, 255)};
    Option<Color> borderColor{this, "BorderColor", "Border color",
                              Color(0, 0, 0, 255)};
    Option<Color> horizontalDividerColor{this, "HorizontalDividerColor",
                                         "Horizontal divider color",
                                         Color(0, 0, 0, 255)};);

FCITX_CONFIGURATION(
    DarkModeConfig, Option<bool> overrideDefault{this, "OverrideDefault",
                                                 _("Override default"), false};
    Option<bool> sameWithLightMode{this, "SameWithLightMode",
                                   _("Same with light mode"), false};
    Option<Color> highlightColor{this, "HighlightColor", "Highlight color",
                                 Color(0, 0, 255, 255)};
    Option<Color> panelColor{this, "PanelColor", "Panel color",
                             Color(255, 255, 255, 255)};
    Option<Color> borderColor{this, "BorderColor", "Border color",
                              Color(0, 0, 0, 255)};
    Option<Color> horizontalDividerColor{this, "HorizontalDividerColor",
                                         "Horizontal divider color",
                                         Color(0, 0, 0, 255)};);

FCITX_CONFIGURATION(BackgroundConfig,
                    Option<std::string> imageUrl{this, "ImageUrl",
                                                 _("Image URL"), ""};
                    Option<bool> blur{this, "Blur", _("Blur"), true};
                    Option<int, IntConstrain> blurRadius{
                        this, "BlurRadius", _("Radius of blur (px)"), 16,
                        IntConstrain(1, 32)};
                    Option<bool> shadow{this, "Shadow", _("Shadow"), true};);

FCITX_CONFIGURATION(
    WebPanelConfig,

    OptionWithAnnotation<std::string, NoSaveAnnotation> preview{
        this, "Preview", _("Type here to preview style")};
    Option<bool> followCursor{this, "FollowCursor", _("Follow cursor"), false};
    Option<candidate_window::theme_t> theme{this, "Theme", _("Theme"),
                                            candidate_window::theme_t::system};
    Option<LightModeConfig> lightMode{this, "LightMode", _("Light mode")};
    Option<DarkModeConfig> darkMode{this, "DarkMode", _("Dark mode")};
    Option<candidate_window::layout_t> layout{
        this, "Layout", _("Layout"), candidate_window::layout_t::horizontal};
    Option<BackgroundConfig> background{this, "Background", _("Background")};
    Option<int, IntConstrain> borderWidth{this, "BorderWidth",
                                          _("Border width (px)"), 1,
                                          IntConstrain(0, BORDER_WIDTH_MAX)};
    Option<int, IntConstrain> borderRadius{
        this, "BorderRadius", _("Border radius (px)"), 6, IntConstrain(0, 100)};
    Option<int, IntConstrain> horizontalDividerWidth{
        this, "HorizontalDividerWidth", _("Horizontal divider width (px)"), 1,
        IntConstrain(0, BORDER_WIDTH_MAX)};);

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
