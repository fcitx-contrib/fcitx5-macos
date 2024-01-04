/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023 Qijia Liu
 */
#include "macosfrontend.h"
#include <fcitx/addonmanager.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputpanel.h>

namespace fcitx {

class MacosInputContext : public InputContext {
public:
    MacosInputContext(MacosFrontend *frontend,
                      InputContextManager &inputContextManager,
                      const std::string &program)
        : InputContext(inputContextManager, program), frontend_(frontend) {
        CapabilityFlags flags = CapabilityFlag::Preedit;
        setCapabilityFlags(flags);
        created();
    }

    ~MacosInputContext() { destroy(); }

    const char *frontend() const override { return "macos"; }

    void commitStringImpl(const std::string &text) override {
        frontend_->commitString(text);
    }

    void deleteSurroundingTextImpl(int offset, unsigned int size) override {}

    void forwardKeyImpl(const ForwardKeyEvent &key) override {}

    void updatePreeditImpl() override {
        auto text = frontend_->instance()->outputFilter(
            this, inputPanel().clientPreedit());
        auto strPreedit = text.toString();
        frontend_->showPreedit(strPreedit, text.cursor());
    }

    void updateInputPanel() {
        const InputPanel &ip = inputPanel();
        // frontend_->updateInputPanel(
        //         filterText(ip.preedit()),
        //         filterText(ip.auxUp()),
        //         filterText(ip.auxDown())
        // );
        std::vector<std::string> candidates;
        int size = 0;
        const auto &list = ip.candidateList();
        if (list) {
            /*
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
            }
            // }
        }
        frontend_->updateCandidateList(candidates, size);
    }

private:
    MacosFrontend *frontend_;

    inline Text filterText(const Text &orig) {
        return frontend_->instance()->outputFilter(this, orig);
    }

    inline std::string filterString(const Text &orig) {
        return filterText(orig).toString();
    }
};

MacosFrontend::MacosFrontend(Instance *instance)
    : instance_(instance), activeIC_(nullptr) {
    eventHandlers_.emplace_back(instance_->watchEvent(
        EventType::InputContextFlushUI, EventWatcherPhase::Default,
        [this](Event &event) {
            auto &e = static_cast<InputContextFlushUIEvent &>(event);
            switch (e.component()) {
            case UserInterfaceComponent::InputPanel: {
                if (activeIC_)
                    activeIC_->updateInputPanel();
                break;
            }
            case UserInterfaceComponent::StatusArea: {
                // statusAreaUpdateCallback();
                break;
            }
            }
        }));
}

void MacosFrontend::setCandidateListCallback(
    const CandidateListCallback &callback) {
    candidateListCallback = callback;
}

void MacosFrontend::setCommitStringCallback(
    const CommitStringCallback &callback) {
    commitStringCallback = callback;
}

void MacosFrontend::setShowPreeditCallback(
    const ShowPreeditCallback &callback) {
    showPreeditCallback = callback;
}

void MacosFrontend::commitString(const std::string &text) {
    commitStringCallback(text);
}

void MacosFrontend::updateCandidateList(
    const std::vector<std::string> &candidates, const int size) {
    candidateListCallback(candidates, size);
}

void MacosFrontend::showPreedit(const std::string &preedit, int caretPos) {
    showPreeditCallback(preedit, caretPos);
}

bool MacosFrontend::keyEvent(Cookie cookie, const Key &key) {
    auto *ic = this->findICByCookie(cookie);
    activeIC_ = ic;
    if (!ic) {
        return false;
    }
    KeyEvent keyEvent(ic, key, false);
    ic->keyEvent(keyEvent);
    return keyEvent.accepted();
}

MacosInputContext *MacosFrontend::findICByCookie(Cookie cookie) {
    auto it = icTable_.find(cookie);
    if (it != icTable_.end()) {
        return it->second;
    }
    return nullptr;
}

Cookie MacosFrontend::createInputContext() {
    auto *ic =
        new MacosInputContext(this, instance_->inputContextManager(), "");
    auto cookie = nextCookie_;
    nextCookie_ += 1;
    icTable_[cookie] = ic;

    // Make sure nextCookie_ is empty.
    while (findICByCookie(nextCookie_)) {
        // SAFETY: wrapping addition.
        nextCookie_ += 1;
    }

    return cookie;
}

void MacosFrontend::destroyInputContext(Cookie cookie) {
    auto *ic = this->findICByCookie(cookie);
    if (ic) {
        icTable_.erase(cookie);
        delete ic;
    }
}

void MacosFrontend::focusIn(Cookie cookie) {
    auto *ic = this->findICByCookie(cookie);
    if (!ic)
        return;
    ic->focusIn();
}

void MacosFrontend::focusOut(Cookie cookie) {
    auto *ic = this->findICByCookie(cookie);
    if (!ic)
        return;
    ic->focusOut();
}

} // namespace fcitx
