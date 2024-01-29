/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023-2024 Fcitx5 macOS contributors
 */
#ifndef _FCITX5_MACOS_MACOSFRONTEND_H_
#define _FCITX5_MACOS_MACOSFRONTEND_H_

#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "macosfrontend-public.h"
#include "webview_candidate_window.hpp"

namespace fcitx {

class MacosInputContext;
enum class PanelShowFlag : int;
using PanelShowFlags = fcitx::Flags<PanelShowFlag>;

class MacosFrontend : public AddonInstance {
public:
    MacosFrontend(Instance *instance);

    Instance *instance() { return instance_; }

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
