#include <unistd.h>
#include <atomic>
#include <filesystem>
#include <sstream>
#include <thread>

#include <fcitx/action.h>
#include <fcitx/menu.h>
#include <fcitx/statusarea.h>
#include <fcitx/userinterfacemanager.h>
#include <keyboard.h>
#include <nlohmann/json.hpp>

#include "fcitx.h"
#include "../macosnotifications/macosnotifications.h"
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

Fcitx::Fcitx() {
    setupLog(true);
    setupEnv();
}

Fcitx::~Fcitx() {
    exit();
    teardown();
}

void Fcitx::setup() {
    setupInstance();
    frontend_ =
        dynamic_cast<fcitx::MacosFrontend *>(addonMgr().addon("macosfrontend"));
}

void Fcitx::teardown() {
    frontend_ = nullptr;
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

void Fcitx::exec() {
    dispatcher_->attach(&instance_->eventLoop());
    instance_->exec();
}

void Fcitx::exit() {
    // the fcitx instance may have been destroyed by stop_fcitx_thread.
    if (dispatcher_)
        dispatcher_->detach();
    if (instance_)
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

fcitx::MacosFrontend *Fcitx::frontend() { return frontend_; }

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

bool in_fcitx_thread() noexcept {
    FCITX_ASSERT(fcitx_thread_started.load());
    return std::this_thread::get_id() == fcitx_thread.get_id();
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

std::string imGetGroupNames() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        nlohmann::json j;
        auto groups = fcitx.instance()->inputMethodManager().groups();
        for (const auto &g : groups) {
            j.push_back(g);
        }
        return j.dump();
    });
}

std::string imGetCurrentGroupName() noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        return fcitx.instance()->inputMethodManager().currentGroup().name();
    });
}

void imSetCurrentGroup(const char *groupName) noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        fcitx.instance()->inputMethodManager().setCurrentGroup(groupName);
    });
}

static nlohmann::json json_describe_im(const fcitx::InputMethodEntry *entry) {
    nlohmann::json j;
    j["name"] = entry->uniqueName();
    j["displayName"] = entry->nativeName() != "" ? entry->nativeName()
                       : entry->name() != ""     ? entry->name()
                                                 : entry->uniqueName();
    return j;
}

std::string imGetCurrentGroup() noexcept {
    return with_fcitx([](Fcitx &fcitx) noexcept {
        nlohmann::json j;
        auto &imMgr = fcitx.instance()->inputMethodManager();
        auto group = imMgr.currentGroup();
        for (const auto &im : group.inputMethodList()) {
            auto entry = imMgr.entry(im.name());
            if (!entry)
                continue;
            j.push_back(json_describe_im(entry));
        }
        return j.dump();
    });
}

std::string imGetGroups() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        auto &imMgr = fcitx.instance()->inputMethodManager();
        auto groups = imMgr.groups();
        nlohmann::json j;
        for (const auto &groupName : groups) {
            if (auto group = imMgr.group(groupName)) {
                nlohmann::json g;
                g["name"] = groupName;
                for (const auto &im : group->inputMethodList()) {
                    if (auto entry = imMgr.entry(im.name()))
                        g["inputMethods"].push_back(json_describe_im(entry));
                }
                j.push_back(g);
            }
        }
        return j.dump();
    });
}

void imSetGroups(const char *json) noexcept {
    auto j = nlohmann::json::parse(json);
    with_fcitx([j = std::move(j)](Fcitx &fcitx) {
        auto &imMgr = fcitx.instance()->inputMethodManager();
        for (const auto &g : j) {
            if (!imMgr.group(g["name"])) {
                imMgr.addEmptyGroup(g["name"]);
            }
            auto updated = *imMgr.group(g["name"]);
            auto &imList = updated.inputMethodList();
            imList.clear();
            for (const auto &im : g["inputMethods"]) {
                imList.emplace_back(im["name"]);
            }
            imMgr.setGroup(updated);
        }
        for (const auto &groupName : imMgr.groups()) {
            if (j.find(groupName) == j.end()) {
                imMgr.removeGroup(groupName);
            }
        }
        imMgr.save();
    });
}

void imSetCurrentIM(const char *imName) noexcept {
    return with_fcitx(
        [=](Fcitx &fcitx) { fcitx.instance()->setCurrentInputMethod(imName); });
}

std::string imGetCurrentIMName() noexcept {
    return with_fcitx(
        [=](Fcitx &fcitx) { return fcitx.instance()->currentInputMethod(); });
}

static nlohmann::json actionToJson(fcitx::Action *action,
                                   fcitx::InputContext *ic) {
    nlohmann::json j;
    j["id"] = action->id();
    j["name"] = action->name();
    j["desc"] = action->shortText(ic);
    if (action->isSeparator()) {
        j["separator"] = true;
    }
    if (action->isCheckable()) {
        bool checked = action->isChecked(ic);
        j["checked"] = checked;
    }
    if (auto *menu = action->menu()) {
        for (auto *subaction : menu->actions()) {
            j["children"].emplace_back(actionToJson(subaction, ic));
        }
    }
    return j;
}

/// Return a json array that describes the menu structure, if the most
/// recent IC has some actions.
///
/// Each array element has a structure like:
/// type Item = { name: str, desc: str, checked?: bool, children: Array<Item>? }
std::string getActions() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        nlohmann::json j = nlohmann::json::array();
        if (auto *ic = fcitx.instance()->mostRecentInputContext()) {
            auto &statusArea = ic->statusArea();
            for (auto *action : statusArea.allActions()) {
                if (!action->id()) {
                    // Not registered with UI manager.
                    continue;
                }
                j.emplace_back(actionToJson(action, ic));
            }
        }
        return j.dump();
    });
}

void activateActionById(int id) noexcept {
    with_fcitx([=](Fcitx &fcitx) {
        auto *action =
            fcitx.instance()->userInterfaceManager().lookupActionById(id);
        if (auto *ic = fcitx.instance()->mostRecentInputContext()) {
            action->activate(ic);
        }
    });
}
