#pragma once

#include <future>
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
    void schedule(std::function<void()>);

    fcitx::AddonManager &addonMgr();
    fcitx::AddonInstance *addon(const std::string &name);
    fcitx::MacosFrontend *macosfrontend();

private:
    void setupLog(bool verbose);
    void setupEnv();
    void setupInstance();
    void setupFrontend();

    std::unique_ptr<fcitx::Instance> instance_;
    std::unique_ptr<fcitx::EventDispatcher> dispatcher_;
    fcitx::MacosFrontend *macosfrontend_;
};

/// Run a function in the fcitx thread and obtain its return value
/// synchronously.
template <class T>
inline T with_fcitx(std::function<T(Fcitx &)> func) {
    auto &fcitx = Fcitx::shared();
    std::promise<T> prom;
    std::future<T> fut = prom.get_future();
    fcitx.schedule([&prom, func = std::move(func), &fcitx]() {
        try {
            T result = func(fcitx);
            prom.set_value(result);
        } catch (...) {
            prom.set_exception(std::current_exception());
        }
    });
    fut.wait();
    return fut.get();
}

/// Run a function in the fcitx thread synchronously.
template <>
inline void with_fcitx(std::function<void(Fcitx &)> func) {
    with_fcitx<int>([func = std::move(func)](Fcitx &fcitx) {
        func(fcitx);
        return 0; // dummy
    });
}
