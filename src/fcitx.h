#pragma once

#include <future>
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "fcitx-public.h"
#include "../macosfrontend/macosfrontend.h"
#include "../webpanel/webpanel.h"

extern fcitx::WebPanel *webpanel_;

/// 'Fcitx' manages the lifecycle of the global Fcitx instance.
class Fcitx final {
public:
    Fcitx();
    ~Fcitx();
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

    fcitx::MacosFrontend *frontend();

private:
    void setupLog();
    void setupEnv();
    void setupInstance();

    std::unique_ptr<fcitx::Instance> instance_;
    std::unique_ptr<fcitx::EventDispatcher> dispatcher_;
    fcitx::MacosFrontend *frontend_;
};

/// Check if we are on the fcitx thread.
bool in_fcitx_thread() noexcept;

/// Run a function in the fcitx thread and obtain its return value
/// synchronously.  If it's called in the fcitx thread, the functor is
/// invoked immediately.
template <class F, class T = std::invoke_result_t<F, Fcitx &>>
inline T with_fcitx(F func) {
    // Avoid deadlock when re-entered.
    if (in_fcitx_thread()) {
        return func(Fcitx::shared());
    }
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
