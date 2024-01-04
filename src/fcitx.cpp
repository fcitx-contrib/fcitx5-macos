#include "fcitx.h"
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>
#include "../macosfrontend/macosfrontend.h"
#include "keyboard.h"
#include "keycode.h"
#include "nativestreambuf.h"

#define APP_CONTENTS_PATH "/Library/Input Methods/Fcitx5.app/Contents"

std::unique_ptr<fcitx::Instance> p_instance;
std::unique_ptr<fcitx::EventDispatcher> p_dispatcher;
fcitx::MacosFrontend *p_frontend = nullptr;
fcitx::ICUUID ic_uuid;

fcitx::KeyboardEngineFactory keyboardFactory;
fcitx::MacosFrontendFactory macosFrontendFactory;
fcitx::StaticAddonRegistry staticAddon = {
    std::make_pair<std::string, fcitx::AddonFactory *>("keyboard",
                                                       &keyboardFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>("macosfrontend",
                                                       &macosFrontendFactory)};

void setupLog(bool verbose) {
    static native_streambuf log_streambuf;
    static std::ostream stream(&log_streambuf);
    fcitx::Log::setLogStream(stream);
    if (verbose) {
        fcitx::Log::setLogRule("*=5,notimedate");
    } else {
        fcitx::Log::setLogRule("notimedate");
    }
}

void start_fcitx() {
    setupLog(true);
    // Separate plugins so that dmg replacement won't remove them
    setenv("FCITX_ADDON_DIRS",
           APP_CONTENTS_PATH "/lib/fcitx5:/usr/local/lib/fcitx5", 1);
    p_instance = std::make_unique<fcitx::Instance>(0, nullptr);
    auto &addonMgr = p_instance->addonManager();
    addonMgr.registerDefaultLoader(&staticAddon);
    p_dispatcher = std::make_unique<fcitx::EventDispatcher>();
    p_dispatcher->attach(&p_instance->eventLoop());
    p_instance->initialize();
    p_frontend =
        dynamic_cast<fcitx::MacosFrontend *>(addonMgr.addon("macosfrontend"));
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
    ic_uuid = p_frontend->createInputContext();
}

bool process_key(uint32_t unicode, uint32_t osxModifiers, uint16_t osxKeycode) {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode),
        osx_modifiers_to_fcitx_keystates(osxModifiers),
        osx_keycode_to_fcitx_keycode(osxKeycode),
    };
    return p_frontend->keyEvent(ic_uuid, parsedKey);
}
