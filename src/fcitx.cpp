#include <filesystem>
#include <mutex>

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

Fcitx &Fcitx::shared() {
    static Fcitx *p_fcitx = nullptr;
    static std::mutex init_once;
    if (p_fcitx) {
        return *p_fcitx;
    } else {
        std::lock_guard<std::mutex> guard(init_once);
        if (p_fcitx)
            return *p_fcitx;
        p_fcitx = new Fcitx;
        return *p_fcitx;
    }
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
    fs::path user_prefix = home / "Library" / "fcitx5";
    std::string fcitx_addon_dirs = join_paths(
        {app_contents_path / "lib" / "fcitx5", user_prefix / "lib" / "fcitx5"});
    std::string xdg_data_dirs = join_paths({user_prefix / "share"});
    std::string libime_model_dirs =
        join_paths({user_prefix / "lib" / "libime"});
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
    auto p_frontend = macosfrontend();
    p_frontend->setCandidateListCallback(
        [](const std::vector<std::string> &candidateList, const int) {
            SwiftFcitx::clearCandidateList();
            for (const auto &candidate : candidateList) {
                SwiftFcitx::appendCandidate(candidate.c_str());
            }
            SwiftFcitx::showCandidatePanel();
        });
    p_frontend->setCommitStringCallback(
        [](const std::string &s) { SwiftFcitx::commit(s.c_str()); });
    p_frontend->setShowPreeditCallback([](const std::string &s, int caretPos) {
        SwiftFcitx::showPreedit(s.c_str(), caretPos);
    });
}

fcitx::AddonManager &Fcitx::addonMgr() { return instance_->addonManager(); }

fcitx::AddonInstance *Fcitx::addon(const std::string &name) {
    return addonMgr().addon(name);
}

fcitx::MacosFrontend *Fcitx::macosfrontend() {
    return dynamic_cast<fcitx::MacosFrontend *>(addon("macosfrontend"));
}

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

void start_fcitx() { Fcitx &fcitx = Fcitx::shared(); }

bool process_key(Cookie cookie, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode),
        osx_modifiers_to_fcitx_keystates(osxModifiers),
        osx_keycode_to_fcitx_keycode(osxKeycode),
    };
    return Fcitx::shared().macosfrontend()->keyEvent(cookie, parsedKey,
                                                     isRelease);
}

uint64_t create_input_context(const char *appId) {
    return Fcitx::shared().macosfrontend()->createInputContext(appId);
}

void destroy_input_context(uint64_t cookie) {
    Fcitx::shared().macosfrontend()->destroyInputContext(cookie);
}

void focus_in(uint64_t cookie) {
    Fcitx::shared().macosfrontend()->focusIn(cookie);
}

void focus_out(uint64_t cookie) {
    Fcitx::shared().macosfrontend()->focusOut(cookie);
}
