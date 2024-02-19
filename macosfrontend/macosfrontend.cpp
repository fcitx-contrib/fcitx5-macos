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
      focusGroup_("macos", instance->inputContextManager()),
      activeIC_(nullptr) {
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

bool MacosFrontend::keyEvent(ICUUID uuid, const Key &key, bool isRelease) {
    auto *ic = this->findIC(uuid);
    if (!ic) {
        return false;
    }
    if (activeIC_ != ic) {
        ic->focusIn();
        activeIC_ = ic;
    }
    KeyEvent keyEvent(ic, key, isRelease);
    ic->keyEvent(keyEvent);

    if (simulateKeyRelease_ && !isRelease && !key.isModifier() &&
        keyEvent.accepted()) {
        auto timeEvent = instance()->eventLoop().addTimeEvent(
            CLOCK_MONOTONIC, now(CLOCK_MONOTONIC) + simulateKeyReleaseDelay_,
            10000, [this, ic, key = key](EventSourceTime *source, uint64_t) {
                FCITX_DEBUG() << "Simulate key release " << key.toString();
                if (activeIC_ == ic) {
                    KeyEvent releaseEvent(ic, key, true);
                    ic->keyEvent(releaseEvent);
                }
                delete source;
                return true;
            });
        // Leak it from unique_ptr, and let it delete itself when it's done.
        auto timeEventPtr = timeEvent.release();
    }

    return keyEvent.accepted();
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
    if (activeIC_ == ic) {
        activeIC_ = nullptr;
    }
    delete ic;
    focusGroup_.setFocusedInputContext(nullptr);
}

void MacosFrontend::focusIn(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusIn();
    activeIC_ = ic;
}

void MacosFrontend::focusOut(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusOut();
    if (activeIC_ == ic)
        activeIC_ = nullptr;
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
    SwiftFrontend::commit(client_, text);
}

void MacosInputContext::updatePreeditImpl() {
    auto preedit =
        frontend_->instance()->outputFilter(this, inputPanel().clientPreedit());
    SwiftFrontend::setPreedit(client_, preedit.toString(), preedit.cursor());
}

std::pair<double, double> MacosInputContext::getCursorCoordinates() {
    double x = 0, y = 0;
    if (!SwiftFrontend::getCursorCoordinates(client_, &x, &y)) {
        FCITX_WARN() << "Failed to get cursor coordinates";
    }
    return std::make_pair(x, y);
}

} // namespace fcitx

bool process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                 uint16_t osxKeycode, bool isRelease) noexcept {
    const fcitx::Key parsedKey{
        osx_unicode_to_fcitx_keysym(unicode, osxKeycode),
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
