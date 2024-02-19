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

namespace fcitx {

class MacosInputContext;
enum class PanelShowFlag : int;
using PanelShowFlags = fcitx::Flags<PanelShowFlag>;

FCITX_CONFIGURATION(MacosFrontendConfig,
                    Option<bool> simulateKeyRelease{this, "SimulateKeyRelease",
                                                    _("Simulate key release")};
                    Option<int, IntConstrain> simulateKeyReleaseDelay{
                        this, "SimulateKeyReleaseDelay",
                        _("Delay of simulated key release in milliseconds"),
                        100, IntConstrain(10, 1500)};);

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

    void updateCandidateList(const std::vector<std::string> &candidates,
                             const std::vector<std::string> &labels, int size,
                             int highlight);
    void selectCandidate(size_t index);
    void updateInputPanel(const fcitx::Text &preedit, const fcitx::Text &auxUp,
                          const fcitx::Text &auxDown);

    ICUUID createInputContext(const std::string &appId, id client);
    void destroyInputContext(ICUUID);
    bool keyEvent(ICUUID, const Key &key, bool isRelease);
    void focusIn(ICUUID);
    void focusOut(ICUUID);

private:
    Instance *instance_;
    std::unique_ptr<candidate_window::CandidateWindow> window_;

    MacosFrontendConfig config_;
    bool simulateKeyRelease_;
    long simulateKeyReleaseDelay_;

    static const inline std::string ConfPath = "conf/macosfrontend.conf";

    FocusGroup focusGroup_; // ensure there is at most one active ic
    MacosInputContext *activeIC_;
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>>
        eventHandlers_;

    inline MacosInputContext *findIC(ICUUID);

    void showInputPanelAsync(bool show);
    PanelShowFlags panelShow_;
    inline void updatePanelShowFlags(bool condition, PanelShowFlag flag) {
        if (condition)
            panelShow_ |= flag;
        else
            panelShow_ = panelShow_.unset(flag);
    }
};

class MacosFrontendFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new MacosFrontend(manager->instance());
    }
};

enum class PanelShowFlag : int {
    HasAuxUp = 1,
    HasAuxDown = 1 << 1,
    HasPreedit = 1 << 2,
    HasCandidates = 1 << 3
};

} // namespace fcitx

#endif
