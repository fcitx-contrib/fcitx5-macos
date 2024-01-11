#pragma once

#include <fcitx/instance.h>
#include <fcitx/addonmanager.h>
#include <fcitx-utils/eventdispatcher.h>

#include "fcitx-public.h"
#include "../macosfrontend/macosfrontend.h"

/// 'Fcitx' manages the lifecycle of the global Fcitx instance.
class Fcitx final {
public:
    Fcitx();
    ~Fcitx() = default;

    static Fcitx &shared();

    void exec();

    fcitx::AddonManager &addonMgr();
    fcitx::AddonInstance *addon(const std::string &name);
    fcitx::MacosFrontend *macosfrontend();

private:
    void setupLog(bool verbose);
    void setupEnv();
    void setupInstance();
    void setupFrontend();

private:
    std::unique_ptr<fcitx::Instance> instance_;
    std::unique_ptr<fcitx::EventDispatcher> dispatcher_;
};
