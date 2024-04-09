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
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/focusgroup.h>
#include <fcitx/instance.h>

#include "macosfrontend-public.h"
#include "webview_candidate_window.hpp"

#define TERMINAL_USE_EN                                                        \
    R"JSON({"appPath": "/System/Applications/Utilities/Terminal.app/", "appName": "Terminal", "appId": "com.apple.Terminal", "imName": "keyboard-us"})JSON"

namespace fcitx {

class MacosInputContext;

struct AppIMAnnotation {
    bool skipDescription() { return false; }
    bool skipSave() { return false; }
    void dumpDescription(RawConfig &config) {
        config.setValueByPath("AppIM", "True");
    }
};

FCITX_CONFIGURATION(
    MacosFrontendConfig,
    OptionWithAnnotation<std::vector<std::string>, AppIMAnnotation>
        appDefaultIM{
            this, "AppDefaultIM", _("App default IM"), {TERMINAL_USE_EN}};
    Option<bool> simulateKeyRelease{this, "SimulateKeyRelease",
                                    _("Simulate key release")};
    Option<int, IntConstrain> simulateKeyReleaseDelay{
        this, "SimulateKeyReleaseDelay",
        _("Delay of simulated key release in milliseconds"), 100,
        IntConstrain(10, 1500)};);

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

    ICUUID createInputContext(const std::string &appId, id client);
    void destroyInputContext(ICUUID);
    std::string keyEvent(ICUUID, const Key &key, bool isRelease);
    void focusIn(ICUUID);
    void focusOut(ICUUID);

private:
    Instance *instance_;

    MacosFrontendConfig config_;
    bool simulateKeyRelease_;
    long simulateKeyReleaseDelay_;

    static const inline std::string ConfPath = "conf/macosfrontend.conf";

    FocusGroup focusGroup_; // ensure there is at most one active ic
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>>
        eventHandlers_;

    inline MacosInputContext *findIC(ICUUID);
    void useAppDefaultIM(const std::string &appId);
};

struct InputContextState {
    std::string commit;
    std::string preedit;
    int cursorPos;
};

class MacosInputContext : public InputContext {
public:
    MacosInputContext(MacosFrontend *frontend,
                      InputContextManager &inputContextManager,
                      const std::string &program, id client);
    ~MacosInputContext();

    const char *frontend() const override { return "macos"; }
    void commitStringImpl(const std::string &text) override;
    void deleteSurroundingTextImpl(int offset, unsigned int size) override {}
    void forwardKeyImpl(const ForwardKeyEvent &key) override {}
    void updatePreeditImpl() override;
    void forcePreedit(bool show);

    std::pair<double, double> getCursorCoordinates(bool followCursor);
    id client() { return client_; }

    void resetState() {
        state_.commit.clear();
        state_.preedit.clear();
        state_.cursorPos = -1;
    }
    std::string getState(bool accepted);

private:
    MacosFrontend *frontend_;
    id client_;
    InputContextState state_;
    bool preeditEmpty = true; // the fake preedit doesn't count here
};

class MacosFrontendFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new MacosFrontend(manager->instance());
    }
};

} // namespace fcitx

#endif
