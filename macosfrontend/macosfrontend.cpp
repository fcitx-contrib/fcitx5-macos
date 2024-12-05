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
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputpanel.h>
#include <nlohmann/json.hpp>

#include "../deps/url-filter/src/url-filter.hpp"
#include "../fcitx5/src/modules/clipboard/clipboard_public.h"

namespace fcitx {

MacosFrontend::MacosFrontend(Instance *instance)
    : instance_(instance),
      focusGroup_("macos", instance->inputContextManager()) {
    reloadConfig();
}

// Runs on the fcitx thread.
void MacosFrontend::pollPasteboard() {
    monitorPasteboardEvent_ = instance_->eventLoop().addTimeEvent(
        CLOCK_MONOTONIC,
        now(CLOCK_MONOTONIC) + *config_.pollPasteboardInterval * 1000000,
        100000, [this](EventSourceTime *time, uint64_t) {
            if (!*config_.monitorPasteboard) {
                return true;
            }
            if (auto clipboard =
                    instance_->addonManager().addon("clipboard", true)) {
                bool isPassword = false;
                std::string str = getPasteboardString(&isPassword);
                if (str.size() <= 2048 /* otherwise unlikely to be URL and will
                                          hang for seconds */
                    && *config_.removeTrackingParameters) {
                    str = url_filter::filterTrackingParameters(str);
                }
                if (!str.empty()) {
                    clipboard->call<IClipboard::setClipboardV2>("", str,
                                                                isPassword);
                    FCITX_DEBUG() << "Add to clipboard: " << str;
                }
            }
            time->setNextInterval(*config_.pollPasteboardInterval * 1000000);
            time->setOneShot();
            return true;
        });
    monitorPasteboardEvent_->setOneShot();
}

void MacosFrontend::updateConfig() {
    simulateKeyRelease_ = config_.simulateKeyRelease.value();
    simulateKeyReleaseDelay_ =
        static_cast<long>(config_.simulateKeyReleaseDelay.value()) * 1000L;
    pollPasteboard();
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
    FCITX_INFO() << "Create IC for " << appId;
    return ic->uuid();
}

void MacosFrontend::destroyInputContext(ICUUID uuid) {
    // InputContext is not owned by InputContextManager.
    // The only exception is when Instance is destroyed,
    // InputContextManager deletes all InputContexts.
    auto ic = findIC(uuid);
    // This check is necessary. Although system sends destroy event immediately
    // after focus out for most scenarios, when using fn+E to call out emoji
    // picker (com.apple.CharacterPaletteIM), the sequence is: user clicks emoji
    // -> picker focus out -> original client focus in -> user starts typing --
    // after a while --> picker destroy. If we don't check whether picker's
    // context has focus, we will reset current focus to nullptr as well, which
    // interrupts user's typing.
    if (ic->hasFocus()) {
        ic->focusOut();
        focusGroup_.setFocusedInputContext(nullptr);
    }
    FCITX_INFO() << "Destroy IC for " << ic->program();
    delete ic;
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

std::string MacosFrontend::focusOut(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return "{}";

    // Fake a switch input method event to call engine's deactivate method and
    // maybe commit and clear preedit synchronously.
    ic->isSyncEvent = true;
    InputContextEvent event(ic, EventType::InputContextSwitchInputMethod);
    auto engine = instance_->inputMethodEngine(ic);
    auto entry = instance_->inputMethodEntry(ic);
    engine->deactivate(*entry, event);
    // At this stage panel is still shown. If removed, a following backspace
    // will commit a BS character in VSCode.
    ic->setDummyPreedit(false);
    auto state = ic->getState(false);
    ic->isSyncEvent = false;

    FCITX_INFO() << "Focus out " << ic->program();
    ic->focusOut();

    return state;
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
    // For async event we need to perform commit, otherwise it's buffered and
    // committed in next commit with a key event. e.g. fcitx commits a ，
    // asynchronously when deleting , after a number/English character.
    if (!isSyncEvent) {
        commitAndSetPreeditAsync();
    }
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
    j["dummyPreedit"] = state_.dummyPreedit;
    j["accepted"] = accepted;
    return j.dump();
}

void MacosInputContext::commitAndSetPreeditAsync() {
    auto state = state_;
    resetState();
    SwiftFrontend::commitAndSetPreeditAsync(client_, state.commit,
                                            state.preedit, state.cursorPos,
                                            state.dummyPreedit);
}

std::pair<double, double>
MacosInputContext::getCursorCoordinates(bool followCursor) {
    // Memorize to avoid jumping to origin on failure.
    static double x = 0, y = 0;
    if (!SwiftFrontend::getCursorCoordinates(client_, followCursor, &x, &y)) {
        FCITX_DEBUG() << "Failed to get cursor coordinates";
    }
    return std::make_pair(x, y);
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(macosfrontend, fcitx::MacosFrontendFactory);

std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease) noexcept {
    const fcitx::Key parsedKey =
        osx_key_to_fcitx_key(unicode, osxModifiers, osxKeycode);
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

std::string focus_out(ICUUID uuid) noexcept {
    return with_fcitx(
        [=](Fcitx &fcitx) { return fcitx.frontend()->focusOut(uuid); });
}
