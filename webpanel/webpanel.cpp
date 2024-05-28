#include <fcitx/inputpanel.h>

#include "fcitx.h"
#include "../macosfrontend/macosfrontend.h"
#include "config/config.h"
#include "webpanel.h"

namespace fcitx {

WebPanel::WebPanel(Instance *instance)
    : instance_(instance),
      window_(std::make_shared<candidate_window::WebviewCandidateWindow>()) {
    window_->set_select_callback([this](size_t index) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            try {
                // Engine is responsible for updating UI
                list->candidate(index).select(ic);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "select candidate index out of range";
            }
        });
    });
    window_->set_page_callback([this](bool next) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            auto *pageableList = list->toPageable();
            if (!pageableList)
                return;
            if (next) {
                pageableList->next();
            } else {
                pageableList->prev();
            }
            // UI is responsible for updating UI
            ic->updateUserInterface(UserInterfaceComponent::InputPanel);
        });
    });
    window_->set_action_callback([this](size_t index, int id) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            try {
                const auto &candidate = list->candidate(index);
                auto *actionableList = list->toActionable();
                if (actionableList && actionableList->hasAction(candidate)) {
                    actionableList->triggerAction(candidate, id);
                }
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        });
    });
    window_->set_init_callback([this]() { reloadConfig(); });
}

void WebPanel::updateConfig() {
    window_->set_layout(config_.typography->layout.value());
    window_->set_theme(config_.theme.value());
    window_->set_cursor_text(config_.cursor->style.value() == CursorStyle::Text
                                 ? config_.cursor->text.value()
                                 : "");
    window_->set_highlight_mark_text(config_.highlight->markStyle.value() ==
                                             HighlightMarkStyle::Text
                                         ? config_.highlight->markText.value()
                                         : "");
    config_.preview.setValue("");
    auto style = configValueToJson(config_).dump();
    window_->set_style(style.c_str());
}

void WebPanel::reloadConfig() {
    readAsIni(config_, ConfPath);
    updateConfig();
}

void WebPanel::setConfig(const RawConfig &config) {
    config_.load(config, true);
    safeSaveAsIni(config_, ConfPath);
    updateConfig();
}

void WebPanel::update(UserInterfaceComponent component,
                      InputContext *inputContext) {
    switch (component) {
    case UserInterfaceComponent::InputPanel: {
        int highlighted = -1;
        const InputPanel &inputPanel = inputContext->inputPanel();
        updateInputPanel(
            instance_->outputFilter(inputContext, inputPanel.preedit()),
            instance_->outputFilter(inputContext, inputPanel.auxUp()),
            instance_->outputFilter(inputContext, inputPanel.auxDown()));
        bool pageable = false;
        bool hasPrev = false;
        bool hasNext = false;
        std::vector<candidate_window::Candidate> candidates;
        int size = 0;
        candidate_window::layout_t layout = config_.typography->layout.value();
        if (const auto &list = inputPanel.candidateList()) {
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
            auto *actionableList = list->toActionable();
            size = list->size();
            for (int i = 0; i < size; i++) {
                auto label = list->label(i).toString();
                // HACK: fcitx5's Linux UI concatenates label and text and
                // expects engine to append a ' ' to label.
                auto length = label.length();
                if (length && label[length - 1] == ' ') {
                    label = label.substr(0, length - 1);
                }
                const auto &candidate = list->candidate(i);
                std::vector<candidate_window::CandidateAction> actions;
                if (actionableList && actionableList->hasAction(candidate)) {
                    for (const auto &action :
                         actionableList->candidateActions(candidate)) {
                        actions.push_back({action.id(), action.text()});
                    }
                }
                candidates.push_back(
                    {instance_->outputFilter(inputContext, candidate.text())
                         .toString(),
                     label,
                     instance_->outputFilter(inputContext, candidate.comment())
                         .toString(),
                     actions});
            }
            highlighted = list->cursorIndex();
            // }
            switch (list->layoutHint()) {
            case CandidateLayoutHint::Vertical:
                layout = candidate_window::layout_t::vertical;
                break;
            case CandidateLayoutHint::Horizontal:
                layout = candidate_window::layout_t::horizontal;
                break;
            default:
                break;
            }
            auto *pageableList = list->toPageable();
            pageable =
                pageableList && config_.typography->showPagingButtons.value();
            if (pageable) {
                hasPrev = pageableList->hasPrev();
                hasNext = pageableList->hasNext();
            }
        }
        window_->set_paging_buttons(pageable, hasPrev, hasNext);
        window_->set_candidates(candidates, highlighted);
        window_->set_layout(layout);
        updatePanelShowFlags(!candidates.empty(), PanelShowFlag::HasCandidates);
        if (auto macosIC = dynamic_cast<MacosInputContext *>(inputContext)) {
            macosIC->setDummyPreedit(
                (panelShow_ & PanelShowFlag::HasPreedit) |
                (panelShow_ & PanelShowFlag::HasCandidates));
            if (!macosIC->isSyncEvent) {
                macosIC->commitAndSetPreeditAsync();
            }
        }
        showAsync(panelShow_);
        break;
    }
    case UserInterfaceComponent::StatusArea:
        // No need to implement.  MacOS will always try to fetch new
        // data, and we don't try to cache anything.
        break;
    }
}

void WebPanel::updateInputPanel(const Text &preedit, const Text &auxUp,
                                const Text &auxDown) {
    auto convert = [](const Text &text) {
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
void WebPanel::showAsync(bool show) {
    std::weak_ptr<candidate_window::CandidateWindow> weakWindow = window_;
    dispatch_async(dispatch_get_main_queue(), ^void() {
      if (auto window = weakWindow.lock()) {
          if (show) {
              if (auto ic = dynamic_cast<MacosInputContext *>(
                      instance_->mostRecentInputContext())) {
                  // MacosInputContext::updatePreeditImpl is executed before
                  // WebPanel::update, so in main thread preedit UI update
                  // happens before here.
                  auto [x, y] =
                      ic->getCursorCoordinates(config_.followCursor.value());
                  window->show(x, y);
              }
          } else {
              window->hide();
          }
      }
    });
}

} // namespace fcitx
