#include <fcitx/inputpanel.h>

#include "fcitx.h"
#include "../macosfrontend/macosfrontend.h"
#include "config/config.h"
#include "webpanel.h"
#include "webview_candidate_window.hpp"

namespace fcitx {

WebPanel::WebPanel(Instance *instance)
    : instance_(instance),
      window_(std::make_shared<candidate_window::WebviewCandidateWindow>()) {
    window_->set_select_callback([this](int index) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                const auto &bulk = list->toBulk();
                if (!bulk) {
                    return;
                }
                try {
                    bulk->candidateFromAll(index).select(ic);
                } catch (const std::invalid_argument &e) {
                    FCITX_ERROR() << "select candidate index out of range";
                }
                return;
            }
            try {
                // Engine is responsible for updating UI
                list->candidate(index).select(ic);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "select candidate index out of range";
            }
        });
    });
    // Doesn't have any effect now.
    window_->set_highlight_callback([this](int index) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                const auto bulkCursor = list->toBulkCursor();
                if (!bulkCursor) {
                    return;
                }
                return bulkCursor->setGlobalCursorIndex(index);
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
    window_->set_scroll_callback(
        [this](int start, int count) { scroll(start, count); });
    window_->set_ask_actions_callback([&](int index) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                const auto &bulk = list->toBulk();
                if (!bulk) {
                    return;
                }
                auto *actionableList = list->toActionable();
                if (!actionableList) {
                    return;
                }
                try {
                    auto &candidate = bulk->candidateFromAll(index);
                    if (actionableList->hasAction(candidate)) {
                        std::vector<candidate_window::CandidateAction> actions;
                        for (const auto &action :
                             actionableList->candidateActions(candidate)) {
                            actions.push_back({action.id(), action.text()});
                        }
                        window_->answer_actions(actions);
                    }
                } catch (const std::invalid_argument &e) {
                    FCITX_ERROR() << "action candidate index out of range";
                }
            }
        });
    });
    window_->set_action_callback([this](int index, int id) {
        with_fcitx([&](Fcitx &fcitx) {
            auto ic = instance_->mostRecentInputContext();
            const auto &list = ic->inputPanel().candidateList();
            if (!list)
                return;
            auto *actionableList = list->toActionable();
            if (!actionableList)
                return;
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                const auto &bulk = list->toBulk();
                if (!bulk) {
                    return;
                }
                try {
                    const auto &candidate = bulk->candidateFromAll(index);
                    if (actionableList->hasAction(candidate)) {
                        actionableList->triggerAction(candidate, id);
                    }
                } catch (const std::invalid_argument &e) {
                    FCITX_ERROR() << "action candidate index out of range";
                }
                return;
            }
            try {
                const auto &candidate = list->candidate(index);
                if (actionableList->hasAction(candidate)) {
                    actionableList->triggerAction(candidate, id);
                }
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        });
    });
    window_->set_init_callback([this]() { reloadConfig(); });
    eventHandler_ = instance_->watchEvent(
        EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
        [this](Event &event) {
            auto &keyEvent = static_cast<KeyEvent &>(event);
            if (keyEvent.key().checkKeyList(*config_.advanced->copyHtml)) {
                if (keyEvent.isRelease()) {
                    return;
                }
                static_cast<candidate_window::WebviewCandidateWindow *>(
                    window_.get())
                    ->copy_html();
                return keyEvent.filterAndAccept();
            }
            if (scrollState_ == candidate_window::scroll_state_t::ready &&
                keyEvent.key().checkKeyList(*config_.scrollMode->expand)) {
                if (keyEvent.isRelease()) {
                    return;
                }
                expand();
                return keyEvent.filterAndAccept();
            }
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                static const std::vector<
                    std::pair<Key, candidate_window::scroll_key_action_t>>
                    selectMap = {
                        {Key(FcitxKey_1),
                         candidate_window::scroll_key_action_t::one},
                        {Key(FcitxKey_2),
                         candidate_window::scroll_key_action_t::two},
                        {Key(FcitxKey_3),
                         candidate_window::scroll_key_action_t::three},
                        {Key(FcitxKey_4),
                         candidate_window::scroll_key_action_t::four},
                        {Key(FcitxKey_5),
                         candidate_window::scroll_key_action_t::five},
                        {Key(FcitxKey_6),
                         candidate_window::scroll_key_action_t::six},
                    };
                for (const auto &pair : selectMap) {
                    if (keyEvent.key().check(pair.first)) {
                        if (keyEvent.isRelease()) {
                            return;
                        }
                        window_->scroll_key_action(pair.second);
                        return keyEvent.filterAndAccept();
                    }
                }
                const std::vector<std::pair<
                    Option<KeyList>, candidate_window::scroll_key_action_t>>
                    actionMap = {
                        {config_.scrollMode->up,
                         candidate_window::scroll_key_action_t::up},
                        {config_.scrollMode->down,
                         candidate_window::scroll_key_action_t::down},
                        {config_.scrollMode->left,
                         candidate_window::scroll_key_action_t::left},
                        {config_.scrollMode->right,
                         candidate_window::scroll_key_action_t::right},
                        {config_.scrollMode->rowStart,
                         candidate_window::scroll_key_action_t::home},
                        {config_.scrollMode->rowEnd,
                         candidate_window::scroll_key_action_t::end},
                        {config_.scrollMode->pageUp,
                         candidate_window::scroll_key_action_t::page_up},
                        {config_.scrollMode->pageDown,
                         candidate_window::scroll_key_action_t::page_down},
                        {config_.scrollMode->commit,
                         candidate_window::scroll_key_action_t::commit},
                    }; // Can't be static because config could be modified.
                for (const auto &pair : actionMap) {
                    if (keyEvent.key().checkKeyList(*pair.first)) {
                        if (!keyEvent.isRelease()) {
                            window_->scroll_key_action(pair.second);
                        }
                        // Must not send release event to engine, which resets
                        // scroll mode.
                        return keyEvent.filterAndAccept();
                    }
                }
                if (keyEvent.key().checkKeyList(
                        *config_.scrollMode->collapse)) {
                    if (keyEvent.isRelease()) {
                        return;
                    }
                    collapse();
                    return keyEvent.filterAndAccept();
                }
            }
        });
}

void WebPanel::updateConfig() {
    window_->set_layout(config_.typography->layout.value());
    window_->set_theme(config_.basic->theme.value());
    window_->set_cursor_text(config_.cursor->style.value() == CursorStyle::Text
                                 ? config_.cursor->text.value()
                                 : "");
    window_->set_highlight_mark_text(config_.highlight->markStyle.value() ==
                                             HighlightMarkStyle::Text
                                         ? config_.highlight->markText.value()
                                         : "");
    auto style = configValueToJson(config_).dump();
    window_->set_style(style.c_str());
    if (auto web = dynamic_cast<candidate_window::WebviewCandidateWindow *>(
            window_.get())) {
        web->unload_plugins();
        using namespace candidate_window;
        uint64_t apis = (config_.advanced->unsafeAPI->curl.value() ? kCurl : 0);
        web->set_api(apis);
        if (*config_.advanced->pluginNotice) {
            web->load_plugins({*config_.advanced->plugins});
        }
    }
}

void WebPanel::reloadConfig() {
    readAsIni(config_, ConfPath);
    updateConfig();
}

inline std::string themePath(const std::string &themeName) {
    return "theme/" + themeName + ".conf";
}

void WebPanel::setConfig(const RawConfig &config) {
    config_.load(config, true);
    auto themeName = *config_.basic->userTheme;
    if (!themeName.empty()) {
        RawConfig raw;
        // Only override current theme when user selects a theme file.
        readAsIni(raw, StandardPath::Type::PkgData, themePath(themeName));
        config_.load(raw, true);
    }
    safeSaveAsIni(config_, ConfPath);
    updateConfig();
}

void WebPanel::setSubConfig(const std::string &path, const RawConfig &config) {
    if (path == "exportcurrenttheme") {
        static auto removedKeys = {"Basic", "ScrollMode", "Advanced"};
        auto themeName = config.value();
        RawConfig raw;
        config_.save(raw);
        for (const auto &key : removedKeys) {
            raw.remove(key);
        }
        safeSaveAsIni(raw, StandardPath::Type::PkgData, themePath(themeName));
    }
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
        candidate_window::writing_mode_t writingMode =
            config_.typography->writingMode.value();
        if (const auto &list = inputPanel.candidateList()) {
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
            const auto &bulk = list->toBulk();
            if (layout == candidate_window::layout_t::horizontal &&
                writingMode ==
                    candidate_window::writing_mode_t::horizontal_tb &&
                *config_.scrollMode->enableScroll && bulk) {
                if (scrollState_ ==
                    candidate_window::scroll_state_t::scrolling) {
                    return expand();
                }
                scrollState_ = candidate_window::scroll_state_t::ready;
            } else {
                scrollState_ = candidate_window::scroll_state_t::none;
            }
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
            auto *pageableList = list->toPageable();
            pageable =
                pageableList && *config_.typography->pagingButtonsStyle !=
                                    PagingButtonsStyle::None;
            if (pageable) {
                hasPrev = pageableList->hasPrev();
                hasNext = pageableList->hasNext();
            }
        } else {
            scrollState_ = candidate_window::scroll_state_t::none;
        }
        window_->set_paging_buttons(pageable, hasPrev, hasNext);
        window_->set_layout(layout);
        window_->set_writing_mode(writingMode);
        // Must be called after set_layout and set_writing_mode so that proper
        // states are read after set.
        window_->set_candidates(candidates, highlighted, scrollState_, false,
                                false);
        updatePanelShowFlags(!candidates.empty(), PanelShowFlag::HasCandidates);
        updateClient(inputContext);
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

void WebPanel::updateClient(InputContext *ic) {
    if (auto macosIC = dynamic_cast<MacosInputContext *>(ic)) {
        // Don't set dummy preedit when switching IM. It will clear current cell
        // in LibreOffice.
        macosIC->setDummyPreedit(bool(panelShow_) &&
                                 !macosIC->inputPanel().transient());
        if (!macosIC->isSyncEvent) {
            macosIC->commitAndSetPreeditAsync();
        }
    }
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
                  auto [x, y] = ic->getCursorCoordinates(
                      config_.basic->followCursor.value());
                  window->show(x, y);
              }
          } else {
              window->hide();
          }
      }
    });
}

void WebPanel::scroll(int start, int count) {
    with_fcitx([&](Fcitx &fcitx) {
        if (scrollState_ == candidate_window::scroll_state_t::none) {
            return;
        }
        auto ic = instance_->mostRecentInputContext();
        if (start < 0) { // collapse
            return collapse();
        }
        const auto &list = ic->inputPanel().candidateList();
        if (!list) {
            return;
        }
        const auto &bulk = list->toBulk();
        if (!bulk) {
            return;
        }
        int size = bulk->totalSize();
        int end = size < 0 ? start + count : std::min(start + count, size);
        bool endReached = size == end;
        std::vector<candidate_window::Candidate> candidates;
        for (int i = start; i < end; ++i) {
            try {
                auto &candidate = bulk->candidateFromAll(i);
                candidates.push_back(
                    {instance_->outputFilter(ic, candidate.text()).toString(),
                     "",
                     instance_->outputFilter(ic, candidate.comment())
                         .toString(),
                     {}});
            } catch (const std::invalid_argument &e) {
                // size == -1 but actual limit is reached
                endReached = true;
                break;
            }
        }
        scrollState_ = candidate_window::scroll_state_t::scrolling;
        window_->set_candidates(candidates, -1, scrollState_, start == 0,
                                endReached);
        updateClient(ic);
        showAsync(true);
    });
}

void WebPanel::expand() {
    scroll(0, 42); // Hard-coded like fcitx5-webview
}

void WebPanel::collapse() {
    auto ic = instance_->mostRecentInputContext();
    // Can't let update to set scrollState_, because it will keep scrollState_
    // scrolling.
    scrollState_ = candidate_window::scroll_state_t::ready;
    update(UserInterfaceComponent::InputPanel, ic);
}

} // namespace fcitx
