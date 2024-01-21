#include <unistd.h>
#include <atomic>
#include <filesystem>
#include <sstream>
#include <thread>

#include <keyboard.h>

#include "fcitx-swift.h"
#include "fcitx.h"
#include "../macosnotifications/macosnotifications.h"
#include "keycode.h"
#include "nativestreambuf.h"

namespace fs = std::filesystem;

#define APP_CONTENTS_PATH "/Library/Input Methods/Fcitx5.app/Contents"

fcitx::KeyboardEngineFactory keyboardFactory;
fcitx::MacosFrontendFactory macosFrontendFactory;
fcitx::MacosNotificationsFactory macosNotificationsFactory;
fcitx::StaticAddonRegistry staticAddons = {
    std::make_pair<std::string, fcitx::AddonFactory *>("keyboard",
                                                       &keyboardFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>("macosfrontend",
                                                       &macosFrontendFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>(
        "notifications", &macosNotificationsFactory)};

static std::string join_paths(const std::vector<fs::path> &paths,
                              char sep = ':');

static std::thread fcitx_thread;
static std::atomic<bool> fcitx_thread_started;

Fcitx &Fcitx::shared() {
    static Fcitx fcitx;
    return fcitx;
}

Fcitx::Fcitx()
    : window_(std::make_unique<candidate_window::WebviewCandidateWindow>()) {
    setupLog(true);
    setupEnv();
}

void Fcitx::setup() {
    setupInstance();
    setupFrontend();
}

void Fcitx::teardown() {
    macosfrontend_ = nullptr;
    instance_.reset();
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
        join_paths({// /Library/Input Methods/Fcitx5.app/Contents/lib/fcitx5
                    app_contents_path / "lib" / "fcitx5",
                    // ~/Library/fcitx5/lib/fcitx5
                    // Install into user_prefix to keep user-installed
                    // plugins when Fcitx.app is reinstalled
                    user_prefix / "lib" / "fcitx5"});
    std::string xdg_data_dirs = join_paths({
        user_prefix / "share" // ~/Library/fcitx5/share
    });
    std::string libime_model_dirs = join_paths({
        user_prefix / "lib" / "libime" // ~/Library/fcitx5/lib/libime
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
        [this](const std::vector<std::string> &candidateList, int,
               int highlighted) {
            SwiftFcitx::clearCandidateList();
            for (const auto &candidate : candidateList) {
                SwiftFcitx::appendCandidate(candidate.c_str());
            }
            SwiftFcitx::showCandidatePanel();
            window_->set_candidates(candidateList, highlighted);
            // Don't read candidateList from callback function as it's
            // transient.
            auto empty = candidateList.empty();
            dispatch_async(dispatch_get_main_queue(), ^void() {
              float x = 0.f, y = 0.f;
              // showPreeditCallback is executed before candidateListCallback,
              // so in main thread preedit UI update happens before here.
              if (!SwiftFcitx::getCursorCoordinates(&x, &y)) {
                  FCITX_WARN() << "Fail to get preedit coordinates";
              }
              if (empty)
                  window_->hide();
              else
                  window_->show(x, y);
            });
        });
    macosfrontend_->setCommitStringCallback(
        [this](const std::string &s) { SwiftFcitx::commit(s.c_str()); });
    macosfrontend_->setShowPreeditCallback(
        [](const std::string &s, int caretPos) {
            SwiftFcitx::setPreedit(s.c_str(), caretPos);
        });
}

void Fcitx::exec() {
    dispatcher_->attach(&instance_->eventLoop());
    instance_->exec();
}

void Fcitx::exit() {
    dispatcher_->detach();
    instance_->exit();
}

void Fcitx::schedule(std::function<void()> func) {
    dispatcher_->schedule(func);
}

fcitx::Instance *Fcitx::instance() { return instance_.get(); }

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

void start_fcitx_thread() noexcept {
    bool expected = false;
    if (!fcitx_thread_started.compare_exchange_strong(expected, true)) {
        FCITX_FATAL()
            << "Trying to start multiple fcitx threads, which is forbidden";
        std::terminate();
    }
    auto &fcitx = Fcitx::shared();
    fcitx.setup();
    // Start the event loop in another thread.
    fcitx_thread = std::thread([&fcitx] { fcitx.exec(); });
}

void stop_fcitx_thread() noexcept {
    auto &fcitx = Fcitx::shared();
    with_fcitx([=](Fcitx &fcitx) { fcitx.exit(); });
    if (fcitx_thread.joinable()) {
        fcitx_thread.join();
    }
    fcitx.teardown();
    fcitx_thread_started = false;
}

void restart_fcitx_thread() noexcept {
    stop_fcitx_thread();
    start_fcitx_thread();
}

bool process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) noexcept {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode),
        osx_modifiers_to_fcitx_keystates(osxModifiers),
        osx_keycode_to_fcitx_keycode(osxKeycode),
    };
    return with_fcitx([=](Fcitx &fcitx) {
        return fcitx.macosfrontend()->keyEvent(uuid, parsedKey, isRelease);
    });
}

ICUUID create_input_context(const char *appId) noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        return fcitx.macosfrontend()->createInputContext(appId);
    });
}

void destroy_input_context(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) {
        fcitx.macosfrontend()->destroyInputContext(uuid);
    });
}

void focus_in(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) { fcitx.macosfrontend()->focusIn(uuid); });
}

void focus_out(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) { fcitx.macosfrontend()->focusOut(uuid); });
}

std::string input_method_groups() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        std::stringstream ss;
        auto groups = fcitx.instance()->inputMethodManager().groups();
        for (const auto &g : groups) {
            ss << g + "\n";
        }
        return std::move(ss).str();
    });
}

std::string input_method_list() noexcept {
    return with_fcitx([](Fcitx &fcitx) noexcept {
        std::stringstream ss;
        auto &imMgr = fcitx.instance()->inputMethodManager();
        auto group = imMgr.currentGroup();
        for (const auto &im : group.inputMethodList()) {
            auto entry = imMgr.entry(im.name());
            if (!entry)
                continue;
            std::string displayName =
                entry->nativeName() != ""   ? entry->nativeName()
                : entry->name() != ""       ? entry->name()
                : entry->uniqueName() != "" ? entry->uniqueName()
                                            : im.name();
            ss << im.name() << ":" << displayName + "\n";
        }
        return std::move(ss).str();
    });
}

void set_current_input_method_group(const char *groupName) noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        fcitx.instance()->inputMethodManager().setCurrentGroup(groupName);
    });
}

std::string get_current_input_method_group() noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        return fcitx.instance()->inputMethodManager().currentGroup().name();
    });
}

void set_current_input_method(const char *imName) noexcept {
    return with_fcitx(
        [=](Fcitx &fcitx) { fcitx.instance()->setCurrentInputMethod(imName); });
}

std::string get_current_input_method() noexcept {
    return with_fcitx(
        [=](Fcitx &fcitx) { return fcitx.instance()->currentInputMethod(); });
}
