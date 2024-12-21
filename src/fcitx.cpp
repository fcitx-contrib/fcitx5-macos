#include <unistd.h>
#include <algorithm>
#include <atomic>
#include <filesystem>
#include <thread>

#include <fcitx-utils/i18n.h>
#include <fcitx/action.h>
#include <fcitx/inputmethodentry.h>
#include <fcitx/inputmethodmanager.h>
#include <fcitx/menu.h>
#include <fcitx/statusarea.h>
#include <fcitx/userinterfacemanager.h>
#include <nlohmann/json.hpp>

#include "fcitx.h"
#include "../fcitx5-beast/src/beast.h"
#include "../keycode/keycode.h"
#include "config/config-public.h"
#include "nativestreambuf.h"

namespace fs = std::filesystem;

#define APP_CONTENTS_PATH "/Library/Input Methods/Fcitx5.app/Contents"

FCITX_DEFINE_STATIC_ADDON_REGISTRY(getStaticAddon)

static std::string join_paths(const std::vector<fs::path> &paths,
                              char sep = ':');

static std::thread fcitx_thread;
static std::atomic<bool> fcitx_thread_started;
static std::string current_locale;

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

// Collect all ~/Library/fcitx5/share/locale/*/LC_MESSAGES/*.mo
std::set<std::string> getPluginDomains(const fs::path &localedir) {
    std::set<std::string> ret;
    try {
        for (const auto &entry : fs::directory_iterator(localedir)) {
            if (!entry.is_directory()) {
                continue;
            }
            fs::path lcMessagesPath = entry.path() / "LC_MESSAGES";
            try {
                for (const auto &file :
                     fs::directory_iterator(lcMessagesPath)) {
                    if (file.path().extension() == ".mo") {
                        ret.insert(file.path().stem());
                    }
                }
            } catch (const std::exception &e) {
                // LC_MESSAGES not exist.
            }
        }
    } catch (const std::exception &e) {
        // localedir not exist.
    }
    return ret;
}

// Must be executed before creating fcitx instance, i.e. loading addons, because
// addons register compile-time domain path, and only 1st call of registerDomain
// counts. The .mo files must exist.
void setupI18N() {
    fs::path home{getenv("HOME")};
    fs::path localedir = home / "Library" / "fcitx5" / "share" / "locale";
    for (const auto &domain : getPluginDomains(localedir)) {
        fcitx::registerDomain(domain.c_str(), localedir.c_str());
    }
}

void Fcitx::setup() {
    setupI18N();
    setupInstance();
    frontend_ =
        dynamic_cast<fcitx::MacosFrontend *>(addonMgr().addon("macosfrontend"));
    auto beast_ = dynamic_cast<fcitx::Beast *>(addonMgr().addon("beast"));
    beast_->setConfigGetter(getConfig);
    beast_->setConfigSetter(setConfig);
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
    std::string libskk_data_path = user_prefix / "share" / "libskk";

    setenv("LIBSKK_DATA_PATH", libskk_data_path.c_str(), 1);
    setenv("FCITX_ADDON_DIRS", fcitx_addon_dirs.c_str(), 1);
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);
    setenv("LIBIME_MODEL_DIRS", libime_model_dirs.c_str(), 1);
    setenv("XKB_CONFIG_EXTRA_PATH", APP_CONTENTS_PATH "/etc/xkb", 1);
    setenv("XKB_CONFIG_ROOT", APP_CONTENTS_PATH "/share/X11/xkb", 1);

    // Set LANGUAGE for libintl-lite.
    std::string val = current_locale;
    size_t dot_pos = val.find('.');
    if (dot_pos != std::string::npos) {
        val = val.substr(0, dot_pos);
    }
    val += ":C";
    setenv("LANGUAGE", val.c_str(), 1);
    setenv("FCITX_LOCALE", val.c_str(), 1);
    FCITX_DEBUG() << "Fcitx LANGUAGE " << val.c_str();

    fcitx::registerDomain(FCITX_GETTEXT_DOMAIN,
                          (app_contents_path / "share" / "locale").c_str());
}

void Fcitx::setupInstance() {
    instance_ = std::make_unique<fcitx::Instance>(0, nullptr);
    dispatcher_ = std::make_unique<fcitx::EventDispatcher>();
    auto &addonMgr = instance_->addonManager();
    addonMgr.registerDefaultLoader(&getStaticAddon());
    instance_->initialize();
    dispatcher_->attach(&instance_->eventLoop());
}

void Fcitx::exec() { instance_->eventLoop().exec(); }

void Fcitx::exit() {
    // the fcitx instance may have been destroyed by stop_fcitx_thread.
    if (dispatcher_)
        dispatcher_->detach();
    if (instance_)
        instance_->eventLoop().exit();
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

void start_fcitx_thread(const char *locale) noexcept {
    bool expected = false;
    if (!fcitx_thread_started.compare_exchange_strong(expected, true)) {
        FCITX_FATAL()
            << "Trying to start multiple fcitx threads, which is forbidden";
        std::terminate();
    }
    if (locale) {
        std::string locale_str = locale;
        std::swap(current_locale, locale_str);
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
    start_fcitx_thread(current_locale.c_str());
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

int imGroupCount() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        return fcitx.instance()->inputMethodManager().groupCount();
    });
}

void imAddToCurrentGroup(const char *imName) noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        auto &imMgr = fcitx.instance()->inputMethodManager();
        auto group = imMgr.currentGroup();
        group.inputMethodList().emplace_back(imName);
        imMgr.setGroup(group);
        imMgr.save();
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
                auto ims = nlohmann::json::array();
                for (const auto &im : group->inputMethodList()) {
                    if (auto entry = imMgr.entry(im.name()))
                        ims.push_back(json_describe_im(entry));
                }
                g["inputMethods"] = ims;
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
        std::unordered_set<std::string> liveGroups;
        for (const auto &g : j) {
            liveGroups.insert(g["name"]);
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
            if (!liveGroups.count(groupName)) {
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

std::string imGetAvailableIMs() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        nlohmann::json j;
        fcitx.instance()->inputMethodManager().foreachEntries(
            [&j](const fcitx::InputMethodEntry &entry) {
                j.push_back(
                    nlohmann::json{{"name", entry.name()},
                                   {"uniqueName", entry.uniqueName()},
                                   {"nativeName", entry.nativeName()},
                                   {"isConfigurable", entry.isConfigurable()},
                                   {"languageCode", entry.languageCode()},
                                   {"icon", entry.icon()},
                                   {"label", entry.label()}});
                return true;
            });
        return j.dump();
    });
}

const char *addon_category_name[] = {"Input Method", "Frontend", "Loader",
                                     "Module", "UI"};

std::string getAddons() noexcept {
    return with_fcitx([](Fcitx &fcitx) {
        auto instance = fcitx.instance();
        auto j = nlohmann::json::array();
        for (auto category :
             {fcitx::AddonCategory::Frontend, fcitx::AddonCategory::Loader,
              fcitx::AddonCategory::Module}) {
            auto addons = nlohmann::json::array();
            auto names = instance->addonManager().addonNames(category);
            for (const auto &name : names) {
                const auto *info = instance->addonManager().addonInfo(name);
                if (!info || !info->isConfigurable()) {
                    continue;
                }
                addons.push_back(
                    nlohmann::json{{"id", info->uniqueName()},
                                   {"name", info->name().match()},
                                   {"comment", info->comment().match()}});
            }
            if (!addons.empty()) {
                j.push_back({{"id", category},
                             {"name", addon_category_name[(int)category]},
                             {"addons", addons}});
            }
        }
        return j.dump();
    });
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
    for (const auto &key : action->hotkey()) {
        auto sym = fcitx_keysym_to_osx_keysym(key.sym());
        if (sym.empty()) {
            continue;
        }
        j["hotkey"].push_back(
            {{"sym", std::move(sym)},
             {"states", fcitx_keystates_to_osx_modifiers(key.states())}});
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
