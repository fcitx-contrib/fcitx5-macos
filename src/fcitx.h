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
    void setup();
    void teardown();

    void exec();
    void exit();
    void schedule(std::function<void()>);

    fcitx::Instance *instance();
    fcitx::AddonManager &addonMgr();
    fcitx::AddonInstance *addon(const std::string &name);

private:
    void setupLog(bool verbose);
    void setupEnv();
    void setupInstance();

    std::unique_ptr<fcitx::Instance> instance_;
    std::unique_ptr<fcitx::EventDispatcher> dispatcher_;
};

/// Run a function in the fcitx thread and obtain its return value
/// synchronously.
template <class F, class T = std::invoke_result_t<F, Fcitx &>>
inline T with_fcitx(F func) {
    auto &fcitx = Fcitx::shared();
    std::promise<T> prom;
    std::future<T> fut = prom.get_future();
    fcitx.schedule([&prom, func = std::move(func), &fcitx]() {
        try {
            if constexpr (std::is_void_v<T>) {
                func(fcitx);
                prom.set_value();
            } else {
                T result = func(fcitx);
                prom.set_value(std::move(result));
            }
        } catch (...) {
            prom.set_exception(std::current_exception());
        }
    });
    fut.wait();
    return fut.get();
}
