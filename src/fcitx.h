#pragma once

#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "fcitx-public.h"
#include "../macosfrontend/macosfrontend.h"

/// 'Fcitx' manages the lifecycle of the global Fcitx instance.
class Fcitx final {
public:
    Fcitx();
    ~Fcitx() = default;
    Fcitx(Fcitx &) = delete;

    static Fcitx &shared();

    void exec();
    void exit();

    fcitx::AddonManager &addonMgr();
    fcitx::AddonInstance *addon(const std::string &name);
    fcitx::MacosFrontend *macosfrontend();

private:
    friend void start_fcitx_thread();

    void setupLog(bool verbose);
    void setupEnv();
    void setupInstance();
    void setupFrontend();

    std::unique_ptr<fcitx::Instance> instance_;
    std::unique_ptr<fcitx::EventDispatcher> dispatcher_;
};
