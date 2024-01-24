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

typedef std::function<void(const std::vector<std::string> &, int, int)>
    CandidateListCallback;
typedef std::function<void(const std::string &)> CommitStringCallback;
typedef std::function<void(const std::string &, int)> ShowPreeditCallback;
typedef std::function<void(const fcitx::Text &, const fcitx::Text &,
                           const fcitx::Text &)>
    UpdateInputPanelCallback;

namespace fcitx {

class MacosInputContext;

class MacosFrontend : public AddonInstance {
public:
    MacosFrontend(Instance *instance);

    Instance *instance() { return instance_; }

    void updateCandidateList(const std::vector<std::string> &candidates,
                             int size, int highlight);
    void selectCandidate(size_t index);
    void commitString(const std::string &text);
    void showPreedit(const std::string &, int);
    void updateInputPanel(const fcitx::Text &preedit, const fcitx::Text &auxUp,
                          const fcitx::Text &auxDown);

    void setCandidateListCallback(const CandidateListCallback &callback);
    void setCommitStringCallback(const CommitStringCallback &callback);
    void setShowPreeditCallback(const ShowPreeditCallback &callback);
    void setUpdateInputPanelCallback(const UpdateInputPanelCallback &callback);

    ICUUID createInputContext(const std::string &appId);
    void destroyInputContext(ICUUID);
    bool keyEvent(ICUUID, const Key &key, bool isRelease);
    void focusIn(ICUUID);
    void focusOut(ICUUID);

private:
    Instance *instance_;
    MacosInputContext *activeIC_;
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>>
        eventHandlers_;

    inline MacosInputContext *findIC(ICUUID);
    CandidateListCallback candidateListCallback =
        [](const std::vector<std::string> &, int, int) {};
    CommitStringCallback commitStringCallback = [](const std::string &) {};
    ShowPreeditCallback showPreeditCallback = [](const std::string &, int) {};
    UpdateInputPanelCallback updateInputPanelCallback =
        [](const fcitx::Text &, const fcitx::Text &, const fcitx::Text &) {};
};

class MacosFrontendFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new MacosFrontend(manager->instance());
    }
};

} // namespace fcitx

#endif
