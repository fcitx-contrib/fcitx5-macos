#include <atomic>
#include <filesystem>
#include <thread>

#include <keyboard.h>

#include "fcitx.h"
#include "keycode.h"
#include "nativestreambuf.h"

namespace fs = std::filesystem;

#define APP_CONTENTS_PATH "/Library/Input Methods/Fcitx5.app/Contents"

fcitx::KeyboardEngineFactory keyboardFactory;
fcitx::MacosFrontendFactory macosFrontendFactory;
fcitx::StaticAddonRegistry staticAddons = {
    std::make_pair<std::string, fcitx::AddonFactory *>("keyboard",
                                                       &keyboardFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>("macosfrontend",
                                                       &macosFrontendFactory)};

static std::string join_paths(const std::vector<fs::path> &paths,
                              char sep = ':');

static std::thread fcitx_thread;
static std::atomic<bool> fcitx_thread_started;

Fcitx &Fcitx::shared() {
    static Fcitx fcitx;
    return fcitx;
}

Fcitx::Fcitx() {
    setupLog(true);
    setupEnv();
    setupInstance();
    setupFrontend();
}

void Fcitx::setupLog(bool verbose) {
    static native_streambuf log_streambuf;
    static std::ostream stream(&log_streambuf);
    fcitx::Log::setLogStream(stream);
    if (verbose) {
        fcitx::Log::setLogRule("*=5,notimedate");
    } else {
        fcitx::Log::setLogRule("notimedate");
    }
}

void Fcitx::setupEnv() {
    fs::path home{getenv("HOME")};
    fs::path app_contents_path{APP_CONTENTS_PATH};
    fs::path user_prefix = home / "Library" / "fcitx5"; // ~/Library/fcitx5
    std::string fcitx_addon_dirs =
        join_paths({// /Library/Input Methods/Fcitx5.app/Contents/lib/fcitx5/
                    app_contents_path / "lib" / "fcitx5",
                    // ~/Library/fcitx5/lib/fcitx5/
                    // Install into user_prefix to keep user-installed
                    // plugins when fcitx.app is reinstalled
                    user_prefix / "lib" / "fcitx5"});
    std::string xdg_data_dirs = join_paths({
        user_prefix / "share" // ~/Library/fcitx5/share/
    });
    std::string libime_model_dirs = join_paths({
        user_prefix / "lib" / "libime" // ~/Library/fcitx5/lib/libime/
    });
    setenv("LANGUAGE", "en", 1); // Needed by libintl-lite
    setenv("FCITX_ADDON_DIRS", fcitx_addon_dirs.c_str(), 1);
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);
    setenv("LIBIME_MODEL_DIRS", libime_model_dirs.c_str(), 1);
}

void Fcitx::setupInstance() {
    instance_ = std::make_unique<fcitx::Instance>(0, nullptr);
    dispatcher_ = std::make_unique<fcitx::EventDispatcher>();
    auto &addonMgr = instance_->addonManager();
    addonMgr.registerDefaultLoader(&staticAddons);
    instance_->initialize();
}

void Fcitx::setupFrontend() {
    macosfrontend_ =
        dynamic_cast<fcitx::MacosFrontend *>(addonMgr().addon("macosfrontend"));
    macosfrontend_->setCandidateListCallback(
        [](const std::vector<std::string> &candidateList, const int) {
            SwiftFcitx::clearCandidateList();
            for (const auto &candidate : candidateList) {
                SwiftFcitx::appendCandidate(candidate.c_str());
            }
            SwiftFcitx::showCandidatePanel();
        });
    macosfrontend_->setCommitStringCallback(
        [](const std::string &s) { SwiftFcitx::commit(s.c_str()); });
    macosfrontend_->setShowPreeditCallback(
        [](const std::string &s, int caretPos) {
            SwiftFcitx::showPreedit(s.c_str(), caretPos);
        });
}

void Fcitx::exec() {
    dispatcher_->attach(&instance_->eventLoop());
    instance_->exec();
}

void Fcitx::exit() { instance_->exit(); }

void Fcitx::schedule(std::function<void()> func) {
    dispatcher_->schedule(func);
}

fcitx::AddonManager &Fcitx::addonMgr() { return instance_->addonManager(); }

fcitx::AddonInstance *Fcitx::addon(const std::string &name) {
    return addonMgr().addon(name);
}

fcitx::MacosFrontend *Fcitx::macosfrontend() { return macosfrontend_; }

/// A helper function to convert a vector of std::filesystem::path
/// into a colon-separated string.
static std::string join_paths(const std::vector<fs::path> &paths, char sep) {
    std::string result;
    for (const auto &path : paths) {
        if (!result.empty()) {
            result += sep;
        }
        result += path;
    }
    return result;
}

void start_fcitx_thread() {
    auto &fcitx = Fcitx::shared();
    bool expected = false;
    if (!fcitx_thread_started.compare_exchange_strong(expected, true)) {
        FCITX_FATAL()
            << "Trying to start multiple fcitx threads, which is forbidden";
        std::terminate();
    }
    // Start the event loop in another thread.
    fcitx_thread = std::thread([&fcitx] { fcitx.exec(); });
}

void stop_fcitx_thread() {
    auto &fcitx = Fcitx::shared();
    fcitx.exit();
    if (fcitx_thread.joinable()) {
        fcitx_thread.join();
    }
}

bool process_key(Cookie cookie, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode),
        osx_modifiers_to_fcitx_keystates(osxModifiers),
        osx_keycode_to_fcitx_keycode(osxKeycode),
    };
    return with_fcitx<bool>([=](Fcitx &fcitx) {
        return fcitx.macosfrontend()->keyEvent(cookie, parsedKey, isRelease);
    });
}

uint64_t create_input_context(const char *appId) {
    return with_fcitx<uint64_t>([=](Fcitx &fcitx) {
        return fcitx.macosfrontend()->createInputContext(appId);
    });
}

void destroy_input_context(uint64_t cookie) {
    with_fcitx<void>([=](Fcitx &fcitx) {
        fcitx.macosfrontend()->destroyInputContext(cookie);
    });
}

void focus_in(uint64_t cookie) {
    with_fcitx<void>(
        [=](Fcitx &fcitx) { fcitx.macosfrontend()->focusIn(cookie); });
}

void focus_out(uint64_t cookie) {
    with_fcitx<void>(
        [=](Fcitx &fcitx) { fcitx.macosfrontend()->focusOut(cookie); });
}
