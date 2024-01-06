/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023 Qijia Liu
 */
#ifndef _FCITX5_MACOS_MACOSFRONTEND_H_
#define _FCITX5_MACOS_MACOSFRONTEND_H_

#include <cstdint>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

/// A short integer to disambiguate different input sessions.
using Cookie = uint64_t;

typedef std::function<void(const std::vector<std::string> &, const int)>
    CandidateListCallback;
typedef std::function<void(const std::string &)> CommitStringCallback;
typedef std::function<void(const std::string &, int)> ShowPreeditCallback;

namespace fcitx {

class MacosInputContext;

class MacosFrontend : public AddonInstance {
public:
    MacosFrontend(Instance *instance);

    Instance *instance() { return instance_; }

    void updateCandidateList(const std::vector<std::string> &candidates,
                             const int size);

    void commitString(const std::string &text);
    void showPreedit(const std::string &, int);
    void setCandidateListCallback(const CandidateListCallback &callback);
    void setCommitStringCallback(const CommitStringCallback &callback);
    void setShowPreeditCallback(const ShowPreeditCallback &callback);

    Cookie createInputContext(const std::string &appId);
    void destroyInputContext(Cookie);
    bool keyEvent(Cookie, const Key &key);
    void focusIn(Cookie);
    void focusOut(Cookie);

    MacosInputContext *findICByCookie(Cookie cookie);

private:
    Instance *instance_;
    MacosInputContext *activeIC_;
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>>
        eventHandlers_;

    // Cookie management.
    // Invariant: icTable_[nextCookie_] does not exist.
    std::unordered_map<Cookie, std::unique_ptr<MacosInputContext>> icTable_;
    Cookie nextCookie_ = 0;

    CandidateListCallback candidateListCallback =
        [](const std::vector<std::string> &, const int) {};
    CommitStringCallback commitStringCallback = [](const std::string &) {};
    ShowPreeditCallback showPreeditCallback = [](const std::string &, int) {};
};

class MacosFrontendFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new MacosFrontend(manager->instance());
    }
};

} // namespace fcitx

#endif
