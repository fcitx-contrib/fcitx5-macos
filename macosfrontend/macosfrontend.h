/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023-2024 Fcitx5 macOS contributors
 */
#ifndef _FCITX5_MACOS_MACOSFRONTEND_H_
#define _FCITX5_MACOS_MACOSFRONTEND_H_

#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/event.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/focusgroup.h>
#include <fcitx/instance.h>

#include "macosfrontend-public.h"

#define TERMINAL_USE_EN                                                        \
    R"JSON({"appPath": "/System/Applications/Utilities/Terminal.app", "appId": "com.apple.Terminal", "imName": "keyboard-us"})JSON"

enum class StatusBar { Hidden, ToggleInputMethod, Menu };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(StatusBar, N_("Hidden"),
                                 N_("Toggle input method"), N_("Menu"))

namespace fcitx {

class MacosInputContext;

struct AppIMAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("AppIM", "True");
    }
};

struct VimModeAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("VimMode", "True");
    }
};

FCITX_CONFIGURATION(
    MacosFrontendConfig,
    OptionWithAnnotation<StatusBar, StatusBarI18NAnnotation> statusBar{
        this, "StatusBar", _("Status bar"), StatusBar::Menu};
    OptionWithAnnotation<std::vector<std::string>, AppIMAnnotation>
        appDefaultIM{
            this, "AppDefaultIM", _("App default IM"), {TERMINAL_USE_EN}};
    OptionWithAnnotation<std::vector<std::string>, VimModeAnnotation> vimMode{
        this, "VimMode", _("Vim mode"), {"org.vim.MacVim"}};
    Option<bool> simulateKeyRelease{this, "SimulateKeyRelease",
                                    _("Simulate key release")};
    Option<int, IntConstrain> simulateKeyReleaseDelay{
        this, "SimulateKeyReleaseDelay",
        _("Delay of simulated key release in milliseconds"), 100,
        IntConstrain(10, 1500)};
    Option<bool> monitorPasteboard{this, "MonitorPasteboard",
                                   _("Monitor Pasteboard"), false};
    Option<bool> removeTrackingParameters{this, "RemoveTrackingParameters",
                                          _("Remove tracking parameters"),
                                          true};
    Option<int, IntConstrain> pollPasteboardInterval{
        this, "PollPasteboardInterval", _("Poll Pasteboard interval (s)"), 2,
        IntConstrain(1, 60)};);

class MacosFrontend : public AddonInstance {
public:
    MacosFrontend(Instance *instance);

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

    ICUUID createInputContext(const std::string &appId,
                              const std::string &accentColor);
    void destroyInputContext(ICUUID);
    std::string keyEvent(ICUUID, const Key &key, bool isRelease,
                         bool isPassword);
    void focusIn(ICUUID, bool isPassword);
    std::string commitComposition(ICUUID uuid);
    void focusOut(ICUUID);

private:
    Instance *instance_;

    MacosFrontendConfig config_;
    bool simulateKeyRelease_;
    long simulateKeyReleaseDelay_;
    std::unique_ptr<EventSourceTime> monitorPasteboardEvent_;
    void pollPasteboard();

    static const inline std::string ConfPath = "conf/macosfrontend.conf";

    FocusGroup focusGroup_; // ensure there is at most one active ic
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>>
        eventHandlers_;
    std::string statusItemText;
    void updateStatusItemText();

    inline MacosInputContext *findIC(ICUUID);
    void useAppDefaultIM(const std::string &appId);
    void useVimMode(const std::string &appId, MacosInputContext *ic);
};

struct InputContextState {
    std::string commit;
    std::string preedit;
    int caretPos;
    bool dummyPreedit;
    bool vimPreedit;
};

class MacosInputContext : public InputContext {
public:
    MacosInputContext(MacosFrontend *frontend,
                      InputContextManager &inputContextManager,
                      const std::string &program,
                      const std::string &accentColor);
    ~MacosInputContext();

    const char *frontend() const override { return "macos"; }
    void commitStringImpl(const std::string &text) override;
    void deleteSurroundingTextImpl(int offset, unsigned int size) override {}
    void forwardKeyImpl(const ForwardKeyEvent &key) override {}
    void updatePreeditImpl() override;

    static std::tuple<double, double, double>
    getCaretCoordinates(bool followCaret);
    std::string getAccentColor() { return accentColor_; }

    void resetState() {
        state_.commit.clear();
        // Don't clear preedit as fcitx may not update it when it's not changed.
    }
    void setDummyPreedit(bool dummyPreedit) {
        state_.dummyPreedit = dummyPreedit;
    }
    void setVimPreedit(bool vimPreedit) { state_.vimPreedit = vimPreedit; }
    std::string popState(bool accepted);
    // Shows whether we are processing a sync event (mainly key down) that needs
    // to return a bool to indicate if it's handled. In this case, commit and
    // preedit need to be set in batch synchronously before returning. Otherwise
    // set them in batch asynchronously.
    bool isSyncEvent = false;
    void commitAndSetPreeditAsync();

    void setPassword(bool isPassword);
    void setVimMode(bool vimMode) { vimMode_ = vimMode; }
    bool vimMode() const { return vimMode_; }

private:
    MacosFrontend *frontend_;
    InputContextState state_;
    std::string accentColor_;
    bool vimMode_ = false;
};

class MacosFrontendFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new MacosFrontend(manager->instance());
    }
};

std::string getPasteboardString(bool *isPassword);

} // namespace fcitx

#endif
