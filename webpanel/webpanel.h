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

enum class CursorStyle { Blink, Static, Text };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(CursorStyle, N_("Blink"), N_("Static"),
                                 N_("Text"))

enum class HighlightMarkStyle { None, Bar, Text };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(HighlightMarkStyle, N_("None"), N_("Bar"),
                                 N_("Text"))

enum class HoverBehavior { None, Move, Add };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(HoverBehavior, N_("None"), N_("Move"),
                                 N_("Add"))

namespace fcitx {

struct NoSaveAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return true; }
    void dumpDescription(RawConfig &config) const {}
};

FCITX_CONFIGURATION(
    LightModeConfig, Option<bool> overrideDefault{this, "OverrideDefault",
                                                  _("Override default"), false};
    Option<Color> highlightColor{this, "HighlightColor", _("Highlight color"),
                                 Color(0, 0, 255, 255)};
    Option<Color> highlightHoverColor{this, "HighlightHoverColor",
                                      _("Highlight color on hover"),
                                      Color(0, 0, 127, 255)};
    Option<Color> highlightTextColor{this, "HighlightTextColor",
                                     _("Highlight text color"),
                                     Color(255, 255, 255, 255)};
    Option<Color> highlightTextPressColor{this, "HighlightTextPressColor",
                                          _("Highlight text color on press"),
                                          Color(127, 127, 127, 255)};
    Option<Color> highlightLabelColor{this, "HighlightLabelColor",
                                      _("Highlight label color"),
                                      Color(255, 255, 255, 255)};
    Option<Color> highlightCommentColor{this, "HighlightCommentColor",
                                        _("Highlight comment color"),
                                        Color(255, 255, 255, 255)};
    Option<Color> highlightMarkColor{this, "HighlightMarkColor",
                                     _("Highlight mark color"),
                                     Color(255, 255, 255, 255)};
    Option<Color> panelColor{this, "PanelColor", _("Panel color"),
                             Color(255, 255, 255, 255)};
    Option<Color> textColor{this, "TextColor", _("Text color"),
                            Color(0, 0, 0, 255)};
    Option<Color> labelColor{this, "LabelColor", _("Label color"),
                             Color(0, 0, 0, 255)};
    Option<Color> commentColor{this, "CommentColor", _("Comment color"),
                               Color(0, 0, 0, 255)};
    Option<Color> pagingButtonColor{this, "PagingButtonColor",
                                    _("Paging button color"),
                                    Color(0, 0, 0, 255)};
    Option<Color> disabledPagingButtonColor{this, "DisabledPagingButtonColor",
                                            _("Disabled paging button color"),
                                            Color(127, 127, 127, 255)};
    Option<Color> preeditColor{this, "PreeditColor", _("Preedit color"),
                               Color(0, 0, 0, 255)};
    Option<Color> borderColor{this, "BorderColor", _("Border color"),
                              Color(0, 0, 0, 255)};
    Option<Color> dividerColor{this, "DividerColor", _("Divider color"),
                               Color(0, 0, 0, 255)};);

FCITX_CONFIGURATION(
    DarkModeConfig, Option<bool> overrideDefault{this, "OverrideDefault",
                                                 _("Override default"), false};
    Option<bool> sameWithLightMode{this, "SameWithLightMode",
                                   _("Same with light mode"), false};
    Option<Color> highlightColor{this, "HighlightColor", "Highlight color",
                                 Color(0, 0, 255, 255)};
    Option<Color> highlightHoverColor{this, "HighlightHoverColor",
                                      _("Highlight color on hover"),
                                      Color(0, 0, 127, 255)};
    Option<Color> highlightTextColor{this, "HighlightTextColor",
                                     _("Highlight text color"),
                                     Color(255, 255, 255, 255)};
    Option<Color> highlightTextPressColor{this, "HighlightTextPressColor",
                                          _("Highlight text color on press"),
                                          Color(127, 127, 127, 255)};
    Option<Color> highlightLabelColor{this, "HighlightLabelColor",
                                      _("Highlight label color"),
                                      Color(255, 255, 255, 255)};
    Option<Color> highlightCommentColor{this, "HighlightCommentColor",
                                        _("Highlight comment color"),
                                        Color(255, 255, 255, 255)};
    Option<Color> highlightMarkColor{this, "HighlightMarkColor",
                                     _("Highlight mark color"),
                                     Color(255, 255, 255, 255)};
    Option<Color> panelColor{this, "PanelColor", "Panel color",
                             Color(0, 0, 0, 255)};
    Option<Color> textColor{this, "TextColor", _("Text color"),
                            Color(255, 255, 255, 255)};
    Option<Color> labelColor{this, "LabelColor", _("Label color"),
                             Color(255, 255, 255, 255)};
    Option<Color> commentColor{this, "CommentColor", _("Comment color"),
                               Color(255, 255, 255, 255)};
    Option<Color> pagingButtonColor{this, "PagingButtonColor",
                                    _("Paging button color"),
                                    Color(255, 255, 255, 255)};
    Option<Color> disabledPagingButtonColor{this, "DisabledPagingButtonColor",
                                            _("Disabled paging button color"),
                                            Color(127, 127, 127, 255)};
    Option<Color> preeditColor{this, "PreeditColor", _("Preedit color"),
                               Color(255, 255, 255, 255)};
    Option<Color> borderColor{this, "BorderColor", "Border color",
                              Color(255, 255, 255, 255)};
    Option<Color> dividerColor{this, "DividerColor", "Divider color",
                               Color(255, 255, 255, 255)};);

FCITX_CONFIGURATION(TypographyConfig,
                    Option<candidate_window::layout_t> layout{
                        this, "Layout", _("Layout"),
                        candidate_window::layout_t::horizontal};
                    Option<bool> showPagingButtons{this, "ShowPagingButtons",
                                                   _("Show paging buttons"),
                                                   false};);

FCITX_CONFIGURATION(BackgroundConfig,
                    Option<std::string> imageUrl{this, "ImageUrl",
                                                 _("Image URL"), ""};
                    Option<bool> blur{this, "Blur", _("Blur"), true};
                    Option<int, IntConstrain> blurRadius{
                        this, "BlurRadius", _("Radius of blur (px)"), 16,
                        IntConstrain(1, 32)};
                    Option<bool> shadow{this, "Shadow", _("Shadow"), true};);

using FontFamilyOption =
    OptionWithAnnotation<std::vector<std::string>, FontAnnotation>;

FCITX_CONFIGURATION(
    FontConfig,
    FontFamilyOption textFontFamily{
        this, "TextFontFamily", _("Text font family"), {""}};
    Option<int, IntConstrain> textFontSize{
        this, "TextFontSize", _("Text font size"), 16, IntConstrain(4, 100)};
    FontFamilyOption labelFontFamily{
        this, "LabelFontFamily", _("Label font family"), {""}};
    Option<int, IntConstrain> labelFontSize{
        this, "LabelFontSize", _("Label font size"), 12, IntConstrain(4, 100)};
    FontFamilyOption commentFontFamily{
        this, "CommentFontFamily", _("Comment font family"), {""}};
    Option<int, IntConstrain> commentFontSize{this, "CommentFontSize",
                                              _("Comment font size"), 12,
                                              IntConstrain(4, 100)};
    FontFamilyOption preeditFontFamily{
        this, "PreeditFontFamily", _("Preedit font family"), {""}};
    Option<int, IntConstrain> preeditFontSize{this, "PreeditFontSize",
                                              _("Preedit font size"), 16,
                                              IntConstrain(4, 100)};
    ExternalOption userFontDir{this, "UserFontDir", _("User font dir"), ""};
    ExternalOption systemFontDir{this, "SystemFontDir", _("System font dir"),
                                 ""};);

FCITX_CONFIGURATION(CursorConfig,
                    Option<CursorStyle> style{this, "Style", _("Style"),
                                              CursorStyle::Blink};
                    Option<std::string> text{this, "Text", _("Text"), "‸"};);

FCITX_CONFIGURATION(
    HighlightConfig,
    Option<HighlightMarkStyle> markStyle{this, "MarkStyle", _("Mark style"),
                                         HighlightMarkStyle::None};
    Option<std::string> markText{this, "MarkText", _("Mark text"), "🐧"};
    Option<HoverBehavior> hoverBehavior{
        this, "HoverBehavior", _("Hover behavior"), HoverBehavior::None};);

FCITX_CONFIGURATION(
    Size,
    Option<int, IntConstrain> borderWidth{this, "BorderWidth",
                                          _("Border width (px)"), 1,
                                          IntConstrain(0, BORDER_WIDTH_MAX)};
    Option<int, IntConstrain> borderRadius{
        this, "BorderRadius", _("Border radius (px)"), 6, IntConstrain(0, 100)};
    Option<int, IntConstrain> margin{this, "Margin", _("Margin (px)"), 0,
                                     IntConstrain(0, 16)};
    Option<int, IntConstrain> highlightRadius{this, "HighlightRadius",
                                              _("Highlight radius (px)"), 0,
                                              IntConstrain(0, 16)};
    Option<int, IntConstrain> topPadding{
        this, "TopPadding", _("Top padding (px)"), 3, IntConstrain(0, 16)};
    Option<int, IntConstrain> rightPadding{
        this, "RightPadding", _("Right padding (px)"), 7, IntConstrain(0, 16)};
    Option<int, IntConstrain> bottomPadding{this, "BottomPadding",
                                            _("Bottom padding (px)"), 3,
                                            IntConstrain(0, 16)};
    Option<int, IntConstrain> leftPadding{
        this, "LeftPadding", _("Left padding (px)"), 7, IntConstrain(0, 16)};
    Option<int, IntConstrain> labelTextGap{this, "LabelTextGap",
                                           _("Gap between label and text (px)"),
                                           6, IntConstrain(0, 16)};
    Option<int, IntConstrain> horizontalDividerWidth{
        this, "HorizontalDividerWidth", _("Horizontal divider width (px)"), 1,
        IntConstrain(0, BORDER_WIDTH_MAX)};);

FCITX_CONFIGURATION(
    WebPanelConfig,

    OptionWithAnnotation<std::string, NoSaveAnnotation> preview{
        this, "Preview", _("Type here to preview style")};
    Option<bool> followCursor{this, "FollowCursor", _("Follow cursor"), false};
    Option<candidate_window::theme_t> theme{this, "Theme", _("Theme"),
                                            candidate_window::theme_t::system};
    Option<LightModeConfig> lightMode{this, "LightMode", _("Light mode")};
    Option<DarkModeConfig> darkMode{this, "DarkMode", _("Dark mode")};
    Option<TypographyConfig> typography{this, "Typography", _("Typography")};
    Option<BackgroundConfig> background{this, "Background", _("Background")};
    Option<FontConfig> font{this, "Font", _("Font")};
    Option<CursorConfig> cursor{this, "Cursor", _("Cursor")};
    Option<HighlightConfig> highlight{this, "Highlight", _("Highlight")};
    Option<Size> size{this, "Size", _("Size")};);

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
