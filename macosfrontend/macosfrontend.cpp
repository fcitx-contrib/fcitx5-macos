/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023-2024 Fcitx5 macOS contributors
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
        auto preedit = frontend_->instance()->outputFilter(
            this, inputPanel().clientPreedit());
        frontend_->showPreedit(preedit.toString(), preedit.cursor());
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

void MacosFrontend::setUpdateInputPanelCallback(
    const UpdateInputPanelCallback &callback) {
    updateInputPanelCallback = callback;
}

void MacosFrontend::commitString(const std::string &text) {
    commitStringCallback(text);
}

void MacosFrontend::updateCandidateList(
    const std::vector<std::string> &candidates,
    const std::vector<std::string> &labels, int size, int highlighted) {
    candidateListCallback(candidates, labels, size, highlighted);
}

void MacosFrontend::selectCandidate(size_t index) {
    if (activeIC_) {
        activeIC_->selectCandidate(index);
    }
}

void MacosFrontend::updateInputPanel(const fcitx::Text &preedit,
                                     const fcitx::Text &auxUp,
                                     const fcitx::Text &auxDown) {
    updateInputPanelCallback(preedit, auxUp, auxDown);
}

void MacosFrontend::showPreedit(const std::string &preedit, int caretPos) {
    showPreeditCallback(preedit, caretPos);
}

bool MacosFrontend::keyEvent(ICUUID uuid, const Key &key, bool isRelease) {
    auto *ic = this->findIC(uuid);
    activeIC_ = ic;
    if (!ic) {
        return false;
    }
    KeyEvent keyEvent(ic, key, isRelease);
    ic->keyEvent(keyEvent);
    return keyEvent.accepted();
}

MacosInputContext *MacosFrontend::findIC(ICUUID uuid) {
    return dynamic_cast<MacosInputContext *>(
        instance_->inputContextManager().findByUUID(uuid));
}

ICUUID MacosFrontend::createInputContext(const std::string &appId) {
    auto ic =
        new MacosInputContext(this, instance_->inputContextManager(), appId);
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
}

void MacosFrontend::focusOut(ICUUID uuid) {
    auto *ic = findIC(uuid);
    if (!ic)
        return;
    ic->focusOut();
}

} // namespace fcitx
