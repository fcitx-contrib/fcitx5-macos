/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023-2024 Fcitx5 macOS contributors
 */
#include "macosfrontend.h"
#include "fcitx.h"
#include "keycode.h"
#include "macosfrontend-swift.h"

#include <CoreFoundation/CoreFoundation.h>
#include <fcitx-utils/event.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputpanel.h>

namespace fcitx {

MacosFrontend::MacosFrontend(Instance *instance)
    : instance_(instance),
      focusGroup_("macos", instance->inputContextManager()) {
    reloadConfig();
}

void MacosFrontend::updateConfig() {
    simulateKeyRelease_ = config_.simulateKeyRelease.value();
    simulateKeyReleaseDelay_ =
        static_cast<long>(config_.simulateKeyReleaseDelay.value()) * 1000L;
}

void MacosFrontend::reloadConfig() {
    readAsIni(config_, ConfPath);
    updateConfig();
}

void MacosFrontend::save() {
    config_.simulateKeyRelease.setValue(simulateKeyRelease_);
    config_.simulateKeyReleaseDelay.setValue(simulateKeyReleaseDelay_ / 1000);
    safeSaveAsIni(config_, ConfPath);
}

std::string MacosFrontend::keyEvent(ICUUID uuid, const Key &key,
                                    bool isRelease) {
    auto *ic = this->findIC(uuid);
    if (!ic) {
        return "{}";
    }
    ic->focusIn();
    KeyEvent keyEvent(ic, key, isRelease);
    ic->isSyncEvent = true;
    ic->keyEvent(keyEvent);
    ic->isSyncEvent = false;

    if (simulateKeyRelease_ && !isRelease && !key.isModifier() &&
        keyEvent.accepted()) {
        auto timeEvent = instance()->eventLoop().addTimeEvent(
            CLOCK_MONOTONIC, now(CLOCK_MONOTONIC) + simulateKeyReleaseDelay_,
            10000, [this, ic, key = key](EventSourceTime *source, uint64_t) {
                FCITX_DEBUG() << "Simulate key release " << key.toString();
                if (instance_->mostRecentInputContext() == ic) {
                    KeyEvent releaseEvent(ic, key, true);
                    ic->keyEvent(releaseEvent);
                }
                delete source;
                return true;
            });
        // Leak it from unique_ptr, and let it delete itself when it's done.
        auto timeEventPtr = timeEvent.release();
    }

    auto state = ic->getState(keyEvent.accepted());
    ic->resetState();
    return state;
}

MacosInputContext *MacosFrontend::findIC(ICUUID uuid) {
    return dynamic_cast<MacosInputContext *>(
        instance_->inputContextManager().findByUUID(uuid));
}

ICUUID MacosFrontend::createInputContext(const std::string &appId, id client) {
    auto ic = new MacosInputContext(this, instance_->inputContextManager(),
                                    appId, client);
    ic->setFocusGroup(&focusGroup_);
    return ic->uuid();
}

void MacosFrontend::destroyInputContext(ICUUID uuid) {
    // InputContext is not owned by InputContextManager.
    // The only exception is when Instance is destroyed,
    // InputContextManager deletes all InputContexts.
    auto ic = findIC(uuid);
    ic->focusOut();
    delete ic;
    focusGroup_.setFocusedInputContext(nullptr);
}

void MacosFrontend::useAppDefaultIM(const std::string &appId) {
    auto appDefaultIM = config_.appDefaultIM.value();
    for (const auto &item : appDefaultIM) {
        try {
            auto j = nlohmann::json::parse(item);
            auto app = j["appId"];
            auto im = j["imName"];
            if (app.is_string() && app.get<std::string>() == appId) {
                if (im.is_string()) {
                    auto imName = im.get<std::string>();
                    imSetCurrentIM(imName.c_str());
                }
                return;
            }
        } catch (const std::exception &e) {
            FCITX_WARN() << "Failed to parse appDefaultIM: " << item;
        }
    }
}

void MacosFrontend::focusIn(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusIn();
    auto program = ic->program();
    FCITX_INFO() << "Focus in " << program;
    useAppDefaultIM(program);
}

void MacosFrontend::focusOut(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusOut();
}

MacosInputContext::MacosInputContext(MacosFrontend *frontend,
                                     InputContextManager &inputContextManager,
                                     const std::string &program, id client)
    : InputContext(inputContextManager, program), frontend_(frontend),
      client_(client) {
    CFRetain(client_);
    CapabilityFlags flags = CapabilityFlag::Preedit;
    setCapabilityFlags(flags);
    created();
}

MacosInputContext::~MacosInputContext() {
    CFRelease(client_);
    destroy();
}

void MacosInputContext::commitStringImpl(const std::string &text) {
    state_.commit += text;
}

void MacosInputContext::updatePreeditImpl() {
    auto preedit =
        frontend_->instance()->outputFilter(this, inputPanel().clientPreedit());
    state_.preedit = preedit.toString();
    state_.cursorPos = preedit.cursor();
}

std::string MacosInputContext::getState(bool accepted) {
    nlohmann::json j;
    j["commit"] = state_.commit;
    j["preedit"] = state_.preedit;
    j["cursorPos"] = state_.cursorPos;
    j["dummyPreedit"] = int(state_.dummyPreedit);
    j["accepted"] = int(accepted);
    return j.dump();
}

void MacosInputContext::commitAndSetPreeditAsync() {
    auto state = state_;
    resetState();
    dispatch_async(dispatch_get_main_queue(), ^void() {
      SwiftFrontend::commitAndSetPreedit(client_, state.commit, state.preedit,
                                         state.cursorPos, state.dummyPreedit);
    });
}

std::pair<double, double>
MacosInputContext::getCursorCoordinates(bool followCursor) {
    double x = 0, y = 0;
    if (!SwiftFrontend::getCursorCoordinates(client_, followCursor, &x, &y)) {
        FCITX_WARN() << "Failed to get cursor coordinates";
    }
    return std::make_pair(x, y);
}

} // namespace fcitx

std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease) noexcept {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode, osxModifiers),
        osx_modifiers_to_fcitx_keystates(osxModifiers),
        osx_keycode_to_fcitx_keycode(osxKeycode),
    };

    return with_fcitx([=](Fcitx &fcitx) {
        auto that = dynamic_cast<fcitx::MacosFrontend *>(fcitx.frontend());
        return that->keyEvent(uuid, parsedKey, isRelease);
    });
}

ICUUID create_input_context(const char *appId, id client) noexcept {
    return with_fcitx([=](Fcitx &fcitx) {
        return fcitx.frontend()->createInputContext(appId, client);
    });
}

void destroy_input_context(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) {
        return fcitx.frontend()->destroyInputContext(uuid);
    });
}

void focus_in(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) { return fcitx.frontend()->focusIn(uuid); });
}

void focus_out(ICUUID uuid) noexcept {
    with_fcitx([=](Fcitx &fcitx) { return fcitx.frontend()->focusOut(uuid); });
}
