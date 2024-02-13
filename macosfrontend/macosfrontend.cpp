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

class MacosInputContext : public InputContext {
public:
    MacosInputContext(MacosFrontend *frontend,
                      InputContextManager &inputContextManager,
                      const std::string &program, id client)
        : InputContext(inputContextManager, program), frontend_(frontend),
          client_(client) {
        CFRetain(client_);
        CapabilityFlags flags = CapabilityFlag::Preedit;
        setCapabilityFlags(flags);
        created();
    }

    ~MacosInputContext() {
        CFRelease(client_);
        destroy();
    }

    const char *frontend() const override { return "macos"; }

    void commitStringImpl(const std::string &text) override {
        SwiftFrontend::commit(client_, text);
    }

    void deleteSurroundingTextImpl(int offset, unsigned int size) override {}

    void forwardKeyImpl(const ForwardKeyEvent &key) override {}

    void updatePreeditImpl() override {
        auto preedit = frontend_->instance()->outputFilter(
            this, inputPanel().clientPreedit());
        SwiftFrontend::setPreedit(client_, preedit.toString(),
                                  preedit.cursor());
    }

    void updateInputPanel() {
        int highlighted = -1;
        const InputPanel &ip = inputPanel();
        frontend_->updateInputPanel(filterText(ip.preedit()),
                                    filterText(ip.auxUp()),
                                    filterText(ip.auxDown()));
        std::vector<std::string> candidates;
        std::vector<std::string> labels;
        int size = 0;
        if (const auto &list = ip.candidateList()) {
            /*  Do not delete; kept for scroll mode.
            const auto &bulk = list->toBulk();
            if (bulk) {
                size = bulk->totalSize();
                // limit candidate count to 16 (for paging)
                const int limit = size < 0 ? 16 : std::min(size, 16);
                for (int i = 0; i < limit; i++) {
                    try {
                        auto &candidate = bulk->candidateFromAll(i);
                        // maybe unnecessary; I don't see anywhere using
            `CandidateWord::setPlaceHolder`
                        // if (candidate.isPlaceHolder()) continue;
                        candidates.emplace_back(filterString(candidate.text()));
                    } catch (const std::invalid_argument &e) {
                        size = static_cast<int>(candidates.size());
                        break;
                    }
                }
            } else {
            */
            size = list->size();
            for (int i = 0; i < size; i++) {
                candidates.emplace_back(
                    filterString(list->candidate(i).text()));
                labels.emplace_back(list->label(i).toString());
            }
            highlighted = list->cursorIndex();
            // }
        }
        frontend_->updateCandidateList(candidates, labels, size, highlighted);
    }

    void selectCandidate(size_t index) {
        const auto &list = inputPanel().candidateList();
        if (!list) {
            return;
        }
        try {
            list->candidate(index).select(this);
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "selectCandidate index out of range";
        }
        return;
    }

    id client() { return client_; }

private:
    MacosFrontend *frontend_;
    id client_;

    inline Text filterText(const Text &orig) {
        return frontend_->instance()->outputFilter(this, orig);
    }

    inline std::string filterString(const Text &orig) {
        return filterText(orig).toString();
    }
};

MacosFrontend::MacosFrontend(Instance *instance)
    : instance_(instance), activeIC_(nullptr),
      window_(std::make_unique<candidate_window::WebviewCandidateWindow>()) {
    reloadConfig();
    eventHandlers_.emplace_back(instance_->watchEvent(
        EventType::InputContextFlushUI, EventWatcherPhase::Default,
        [this](Event &event) {
            auto &e = static_cast<InputContextFlushUIEvent &>(event);
            switch (e.component()) {
            case UserInterfaceComponent::InputPanel: {
                if (activeIC_)
                    activeIC_->updateInputPanel();
                else
                    panelShow_ = false; // focus out
                showInputPanelAsync(panelShow_);
                break;
            }
            case UserInterfaceComponent::StatusArea: {
                // statusAreaUpdateCallback();
                break;
            }
            }
        }));
    window_->set_select_callback(
        [this](size_t index) { selectCandidate(index); });
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

void MacosFrontend::updateInputPanel(const fcitx::Text &preedit,
                                     const fcitx::Text &auxUp,
                                     const fcitx::Text &auxDown) {
    auto convert = [](const fcitx::Text &text) {
        std::vector<std::pair<std::string, int>> ret;
        for (int i = 0; i < text.size(); ++i) {
            ret.emplace_back(
                make_pair(text.stringAt(i), text.formatAt(i).toInteger()));
        }
        return ret;
    };
    window_->update_input_panel(convert(preedit), preedit.cursor(),
                                convert(auxUp), convert(auxDown));
    updatePanelShowFlags(!preedit.empty(), PanelShowFlag::HasPreedit);
    updatePanelShowFlags(!auxUp.empty(), PanelShowFlag::HasAuxUp);
    updatePanelShowFlags(!auxDown.empty(), PanelShowFlag::HasAuxDown);
}

/// Before calling this, the panel states must already be initialized
/// synchronously, by using set_candidates, etc.
void MacosFrontend::showInputPanelAsync(bool show) {
    dispatch_async(dispatch_get_main_queue(), ^void() {
      if (show) {
          double x = 0, y = 0;
          // showPreeditCallback is executed before candidateListCallback,
          // so in main thread preedit UI update happens before here.
          if (activeIC_ && !SwiftFrontend::getCursorCoordinates(
                               activeIC_->client(), &x, &y)) {
              FCITX_WARN() << "Fail to get preedit coordinates";
          }
          window_->show(x, y);
      } else {
          window_->hide();
      }
    });
}

void MacosFrontend::updateCandidateList(
    const std::vector<std::string> &candidateList,
    const std::vector<std::string> &labelList, int size, int highlight) {
    window_->set_candidates(candidateList, labelList, highlight);
    updatePanelShowFlags(!candidateList.empty(), PanelShowFlag::HasCandidates);
}

void MacosFrontend::selectCandidate(size_t index) {
    if (activeIC_) {
        activeIC_->selectCandidate(index);
    }
}

bool MacosFrontend::keyEvent(ICUUID uuid, const Key &key, bool isRelease) {
    auto *ic = this->findIC(uuid);
    if (activeIC_ != ic) {
        if (activeIC_)
            activeIC_->focusOut();
        ic->focusIn();
        activeIC_ = ic;
    }
    if (!ic) {
        return false;
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
}

void MacosFrontend::focusIn(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusIn();
    if (activeIC_)
        activeIC_->focusOut();
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
