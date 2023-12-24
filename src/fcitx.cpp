#include "fcitx.h"
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>
#include "../macosfrontend/macosfrontend.h"
#include "nativestreambuf.h"

#define APP_CONTENTS_PATH "/Library/Input Methods/Fcitx5.app/Contents"

std::unique_ptr<fcitx::Instance> p_instance;
std::unique_ptr<fcitx::EventDispatcher> p_dispatcher;
fcitx::MacosFrontend *p_frontend = nullptr;
fcitx::ICUUID ic_uuid;

fcitx::MacosFrontendFactory macosFrontendFactory;
fcitx::StaticAddonRegistry staticAddon = {
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
    ic_uuid = p_frontend->createInputContext();
}

bool process_key(std::string key) {
    const fcitx::Key parsedKey{fcitx::Key::keySymFromString(key)};
    return p_frontend->keyEvent(ic_uuid, parsedKey);
}
