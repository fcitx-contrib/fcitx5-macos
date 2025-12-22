#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx-config/enum.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "webview_candidate_window.hpp"

#define BORDER_WIDTH_MAX 10

namespace candidate_window {
FCITX_CONFIG_ENUM_NAME_WITH_I18N(theme_t, N_("System"), N_("Light"), N_("Dark"))
FCITX_CONFIG_ENUM_NAME_WITH_I18N(layout_t, N_("Horizontal"), N_("Vertical"))
FCITX_CONFIG_ENUM_NAME_WITH_I18N(writing_mode_t, N_("Horizontal top-bottom"),
                                 N_("Vertical right-left"),
                                 N_("Vertical left-right"))

FCITX_CONFIG_ENUM_NAME_WITH_I18N(blur_t, N_("None"), N_("System"), N_("Blur"),
                                 N_("Liquid Glass"))
} // namespace candidate_window

enum class DefaultTheme { System, MacOS26, MacOS15 };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(DefaultTheme, N_("System"), N_("macOS 26"),
                                 N_("macOS 15"))

enum class PagingButtonsStyle { None, Arrow, Triangle };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(PagingButtonsStyle, N_("None"), N_("Arrow"),
                                 N_("Triangle"))

enum class CaretStyle { Blink, Static, Text };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(CaretStyle, N_("Blink"), N_("Static"),
                                 N_("Text"))

enum class HighlightMarkStyle { None, Bar, Text };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(HighlightMarkStyle, N_("None"), N_("Bar"),
                                 N_("Text"))

enum class HoverBehavior { None, Move, Add };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(HoverBehavior, N_("None"), N_("Move"),
                                 N_("Add"))

namespace fcitx {

struct UserThemeAnnotation {
    bool skipDescription() { return false; }
    // Skip save so that when theme editor passes a non-empty string, we know
    // user actually selects a theme file. Comparing new value with old (saved)
    // value makes no sense because user may replace a theme with another theme
    // that has the same file name.
    bool skipSave() { return true; }
    void dumpDescription(RawConfig &config) const {
        config.setValueByPath("UserTheme", "True");
    }
};

struct ImageAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("Image", "True");
    }
};

struct CssAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("CSS", "True");
    }
};

struct PluginAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("Plugin", "True");
    }
};

FCITX_CONFIGURATION(
    BasicConfig,
    Option<bool> followCaret{this, "FollowCaret", _("Follow caret"), false};
    OptionWithAnnotation<candidate_window::theme_t,
                         candidate_window::theme_tI18NAnnotation>
        theme{this, "Theme", _("Theme"), candidate_window::theme_t::system};
    OptionWithAnnotation<DefaultTheme, DefaultThemeI18NAnnotation> defaultTheme{
        this, "DefaultTheme", _("Default theme"), DefaultTheme::System};
    OptionWithAnnotation<std::string, UserThemeAnnotation> userTheme{
        this, "UserTheme", _("User theme"), ""};
    ExternalOption exportCurrentTheme{this, "ExportCurrentTheme",
                                      _("Export current theme"), ""};);

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
    Option<Color> auxColor{this, "AuxColor", _("Indicator text color"),
                           Color(0, 0, 0, 255)};
    Option<Color> preeditColorPreCaret{this, "PreeditColorPreCaret",
                                       _("Preedit color pre-caret"),
                                       Color(0, 0, 0, 255)};
    Option<Color> preeditColorCaret{this, "PreeditColorCaret",
                                    _("Preedit caret color"),
                                    Color(0, 0, 0, 255)};
    Option<Color> preeditColorPostCaret{this, "PreeditColorPostCaret",
                                        _("Preedit color post-caret"),
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

    Option<Color> auxColor{this, "AuxColor", _("Indicator text color"),
                           Color(255, 255, 255, 255)};
    Option<Color> preeditColorPreCaret{this, "PreeditColorPreCaret",
                                       _("Preedit color pre-caret"),
                                       Color(255, 255, 255, 255)};
    Option<Color> preeditColorCaret{this, "PreeditColorCaret",
                                    _("Preedit caret color"),
                                    Color(255, 255, 255, 255)};
    Option<Color> preeditColorPostCaret{this, "PreeditColorPostCaret",
                                        _("Preedit color post-caret"),
                                        Color(255, 255, 255, 255)};
    Option<Color> borderColor{this, "BorderColor", _("Border color"),
                              Color(255, 255, 255, 255)};
    Option<Color> dividerColor{this, "DividerColor", _("Divider color"),
                               Color(255, 255, 255, 255)};);

FCITX_CONFIGURATION(
    ScrollConfig,
    Option<bool> enableScroll{this, "EnableScroll", _("Enable scroll"), true};
    Option<bool> autoExpand{this, "AutoExpand", _("Auto expand"), false};
    Option<bool> showScrollBar{this, "ShowScrollBar", _("Show scroll bar"),
                               true};
    Option<bool> animation{this, "Animation", _("Animation"), true};
    Option<int, IntConstrain> maxRowCount{
        this, "MaxRowCount", _("Max row count"), 6, IntConstrain(2, 10)};
    Option<int, IntConstrain> maxColumnCount{
        this, "MaxColumnCount", _("Max column count"), 6, IntConstrain(2, 10)};
    Option<KeyList> expand{
        this, "Expand", _("Expand"), {Key(FcitxKey_equal), Key(FcitxKey_Down)}};
    Option<KeyList> collapse{
        this, "Collapse", _("Collapse"), {Key(FcitxKey_minus)}};
    Option<KeyList> up{
        this, "Up", _("Up"), {Key(FcitxKey_minus), Key(FcitxKey_Up)}};
    Option<KeyList> down{
        this, "Down", _("Down"), {Key(FcitxKey_equal), Key(FcitxKey_Down)}};
    Option<KeyList> left{this, "Left", _("Left"), {Key(FcitxKey_Left)}};
    Option<KeyList> right{this, "Right", _("Right"), {Key(FcitxKey_Right)}};
    Option<KeyList> rowStart{
        this, "RowStart", _("Row start"), {Key(FcitxKey_Home)}};
    Option<KeyList> rowEnd{this, "RowEnd", _("Row end"), {Key(FcitxKey_End)}};
    Option<KeyList> pageUp{
        this, "PageUp", _("Page up"), {Key(FcitxKey_Page_Up)}};
    Option<KeyList> pageDown{
        this, "PageDown", _("Page down"), {Key(FcitxKey_Page_Down)}};
    Option<KeyList> commit{this, "Commit", _("Commit"), {Key(FcitxKey_space)}};
    Option<KeyList> selectCandidate{
        this, "SelectCandidate", _("Select candidate"), {}};
    Option<bool> useMainKeyboardNumberKeys{
        this, "UseMainKeyboardNumberKeys",
        _("Use main keyboard number keys to select candidate"), true};
    Option<bool> useKeypadNumberKeys{
        this, "UseKeypadNumberKeys",
        _("Use keypad number keys to select candidate"), false};
    Option<bool> optimizeForHyperKey{this, "OptimizeForHyperKey",
                                     _("Optimize for Hyper key"), true};);

FCITX_CONFIGURATION(
    TypographyConfig,
    OptionWithAnnotation<candidate_window::layout_t,
                         candidate_window::layout_tI18NAnnotation>
        layout{this, "Layout", _("Layout"),
               candidate_window::layout_t::horizontal};
    OptionWithAnnotation<candidate_window::writing_mode_t,
                         candidate_window::writing_mode_tI18NAnnotation>
        writingMode{this, "WritingMode", _("Writing mode"),
                    candidate_window::writing_mode_t::horizontal_tb};
    Option<bool> typographyAwarenessForIM{this, "TypographyAwarenessForIM",
                                          _("Typography awareness for IM"),
                                          true};
    Option<bool> verticalCommentsAlignRight{this, "VerticalCommentsAlignRight",
                                            _("Vertical comments align right"),
                                            false};
    OptionWithAnnotation<PagingButtonsStyle, PagingButtonsStyleI18NAnnotation>
        pagingButtonsStyle{this, "PagingButtonsStyle",
                           _("Paging buttons style"),
                           PagingButtonsStyle::Arrow};);

FCITX_CONFIGURATION(
    BackgroundConfig,
    OptionWithAnnotation<std::string, ImageAnnotation> imageUrl{
        this, "ImageUrl", _("Image"), ""};
    Option<bool> keepPanelColorWhenHasImage{
        this, "KeepPanelColorWhenHasImage",
        _("Keep panel color when has image"), false};
    OptionWithAnnotation<candidate_window::blur_t,
                         candidate_window::blur_tI18NAnnotation>
        blur{this, "Blur", _("Blur"), candidate_window::blur_t::system};
    Option<bool> shadow{this, "Shadow", _("Shadow"), true};);

using FontFamilyOption =
    OptionWithAnnotation<std::vector<std::string>, FontAnnotation>;

FCITX_CONFIGURATION(
    FontConfig,
    FontFamilyOption textFontFamily{
        this, "TextFontFamily", _("Text font family"), {""}};
    Option<int, IntConstrain> textFontSize{
        this, "TextFontSize", _("Text font size"), 16, IntConstrain(4, 100)};
    Option<int, IntConstrain> textFontWeight{this, "TextFontWeight",
                                             _("Text font weight"), 400,
                                             IntConstrain(1, 1000)};
    FontFamilyOption labelFontFamily{
        this, "LabelFontFamily", _("Label font family"), {""}};
    Option<int, IntConstrain> labelFontSize{
        this, "LabelFontSize", _("Label font size"), 12, IntConstrain(4, 100)};
    Option<int, IntConstrain> labelFontWeight{this, "LabelFontWeight",
                                              _("Label font weight"), 400,
                                              IntConstrain(1, 1000)};
    FontFamilyOption commentFontFamily{
        this, "CommentFontFamily", _("Comment font family"), {""}};
    Option<int, IntConstrain> commentFontSize{this, "CommentFontSize",
                                              _("Comment font size"), 12,
                                              IntConstrain(4, 100)};
    Option<int, IntConstrain> commentFontWeight{this, "CommentFontWeight",
                                                _("Comment font weight"), 400,
                                                IntConstrain(1, 1000)};
    FontFamilyOption preeditFontFamily{
        this, "PreeditFontFamily", _("Preedit font family"), {""}};
    Option<int, IntConstrain> preeditFontSize{this, "PreeditFontSize",
                                              _("Preedit font size"), 16,
                                              IntConstrain(4, 100)};
    Option<int, IntConstrain> preeditFontWeight{this, "PreeditFontWeight",
                                                _("Preedit font weight"), 400,
                                                IntConstrain(1, 1000)};
    ExternalOption userFontDir{this, "UserFontDir", _("User font dir"), ""};
    ExternalOption systemFontDir{this, "SystemFontDir", _("System font dir"),
                                 ""};);

FCITX_CONFIGURATION(CaretConfig,
                    OptionWithAnnotation<CaretStyle, CaretStyleI18NAnnotation>
                        style{this, "Style", _("Style"), CaretStyle::Blink};
                    Option<std::string> text{this, "Text", _("Text"), "‸"};);

FCITX_CONFIGURATION(
    HighlightConfig,
    OptionWithAnnotation<HighlightMarkStyle, HighlightMarkStyleI18NAnnotation>
        markStyle{this, "MarkStyle", _("Mark style"), HighlightMarkStyle::None};
    Option<std::string> markText{this, "MarkText", _("Mark text"), "🐧"};
    OptionWithAnnotation<HoverBehavior, HoverBehaviorI18NAnnotation>
        hoverBehavior{this, "HoverBehavior", _("Hover behavior"),
                      HoverBehavior::None};);

FCITX_CONFIGURATION(
    Size, Option<bool> overrideDefault{this, "OverrideDefault",
                                       _("Override default"), false};
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
    Option<int, IntConstrain> labelTextGap{
        this, "LabelTextGap", _("Gap between label, text and comment (px)"), 6,
        IntConstrain(0, 16)};
    Option<int, IntConstrain> verticalMinWidth{this, "VerticalMinWidth",
                                               _("Vertical minimum width (px)"),
                                               200, IntConstrain(0, 960)};
    Option<int, IntConstrain> scrollCellWidth{this, "ScrollCellWidth",
                                              _("Scroll cell width (px)"), 65,
                                              IntConstrain(40, 100)};
    Option<int, IntConstrain> horizontalDividerWidth{
        this, "HorizontalDividerWidth", _("Horizontal divider width (px)"), 1,
        IntConstrain(0, BORDER_WIDTH_MAX)};);

FCITX_CONFIGURATION(UnsafeAPI, Option<bool> curl{this, "EnableUnsafeCurlAPI",
                                                 "curl", false};);

FCITX_CONFIGURATION(
    Advanced,
    OptionWithAnnotation<std::string, CssAnnotation> userCss{
        this, "UserCss", _("User CSS"), {}};
    Option<KeyList> copyHtml{this, "CopyHtml", _("Copy HTML"), {}};
    ExternalOption pluginDir{this, "PluginDir", _("Plugin dir"), ""};
    Option<bool> pluginNotice{this, "PluginNotice",
                              _("I know there may be risks for using plugins"),
                              false};
    OptionWithAnnotation<std::vector<std::string>, PluginAnnotation> plugins{
        this, "Plugins", _("Plugins"), {}};
    Option<UnsafeAPI> unsafeAPI{this, "UnsafeAPI",
                                _("Dangerous API for JavaScript plugins")};);

FCITX_CONFIGURATION(
    WebPanelConfig, Option<BasicConfig> basic{this, "Basic", _("Basic")};
    Option<LightModeConfig> lightMode{this, "LightMode", _("Light mode")};
    Option<DarkModeConfig> darkMode{this, "DarkMode", _("Dark mode")};
    Option<TypographyConfig> typography{this, "Typography", _("Typography")};
    Option<ScrollConfig> scrollMode{this, "ScrollMode", _("Scroll mode")};
    Option<BackgroundConfig> background{this, "Background", _("Background")};
    Option<FontConfig> font{this, "Font", _("Font")};
    Option<CaretConfig> caret{this, "Caret", _("Caret")};
    Option<HighlightConfig> highlight{this, "Highlight", _("Highlight")};
    Option<Size> size{this, "Size", _("Size")};
    Option<Advanced> advanced{this, "Advanced", _("Advanced")};);

enum class PanelShowFlag : int;
using PanelShowFlags = Flags<PanelShowFlag>;

class WebPanel final : public UserInterface {
public:
    WebPanel(Instance *);
    virtual ~WebPanel() = default;

    void updateConfig();
    void reloadConfig() override;
    const Configuration *getConfig() const override { return &config_; }
    void setConfig(const RawConfig &config) override;
    void setSubConfig(const std::string &path,
                      const RawConfig &config) override;

    Instance *instance() { return instance_; }

    bool available() override { return true; }
    void suspend() override {}
    void resume() override {}
    void update(UserInterfaceComponent component,
                InputContext *inputContext) override;

    void updateInputPanel(const Text &preedit, const Text &auxUp,
                          const Text &auxDown);
    void applyAppAccentColor(const std::string &accentColor);

private:
    Instance *instance_;
    std::shared_ptr<candidate_window::WebviewCandidateWindow> window_;

    static const inline std::string ConfPath = "conf/webpanel.conf";
    WebPanelConfig config_;
    std::unique_ptr<HandlerTableEntry<EventHandler>> eventHandler_;

    void updateClient(InputContext *ic);
    void showAsync(bool show);
    PanelShowFlags panelShow_;
    inline void updatePanelShowFlags(bool condition, PanelShowFlag flag) {
        if (condition)
            panelShow_ |= flag;
        else
            panelShow_ = panelShow_.unset(flag);
    }

    candidate_window::scroll_state_t scrollState_ =
        candidate_window::scroll_state_t::none;
    void scroll(int start, int count);
    void expand();
    void collapse();
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
