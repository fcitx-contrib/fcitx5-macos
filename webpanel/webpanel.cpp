#include <fcitx/inputpanel.h>

#include "fcitx.h"
#include "../macosfrontend/macosfrontend.h"
#include "config/config.h"
#include "webpanel.h"

namespace fcitx {

WebPanel::WebPanel(Instance *instance)
    : instance_(instance),
      window_(std::make_unique<candidate_window::WebviewCandidateWindow>()) {
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
                try {
                    bulkCursor->setGlobalCursorIndex(index);
                } catch (const std::invalid_argument &e) {
                    FCITX_ERROR() << "highlight candidate index out of range";
                }
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
    window_->set_scroll_callback([this](int start, int count) {
        with_fcitx([=, this](Fcitx &fcitx) { scroll(start, count); });
    });
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
                        dispatch_async(dispatch_get_main_queue(), ^{
                          window_->answer_actions(actions);
                        });
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
            const auto key = keyEvent.key();
            if (key.checkKeyList(*config_.advanced->copyHtml)) {
                if (keyEvent.isRelease()) {
                    return;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                  window_->copy_html();
                });
                return keyEvent.filterAndAccept();
            }
            if (scrollState_ == candidate_window::scroll_state_t::ready &&
                key.checkKeyList(*config_.scrollMode->expand)) {
                if (keyEvent.isRelease()) {
                    return;
                }
                expand();
                return keyEvent.filterAndAccept();
            }
            if (scrollState_ == candidate_window::scroll_state_t::scrolling) {
                static const std::vector<candidate_window::scroll_key_action_t>
                    selectActions = {
                        candidate_window::scroll_key_action_t::one,
                        candidate_window::scroll_key_action_t::two,
                        candidate_window::scroll_key_action_t::three,
                        candidate_window::scroll_key_action_t::four,
                        candidate_window::scroll_key_action_t::five,
                        candidate_window::scroll_key_action_t::six,
                        candidate_window::scroll_key_action_t::seven,
                        candidate_window::scroll_key_action_t::eight,
                        candidate_window::scroll_key_action_t::nine,
                        candidate_window::scroll_key_action_t::zero,
                    };
                static const KeyList mainKeyboardNumberKeys = {
                    Key(FcitxKey_1), Key(FcitxKey_2), Key(FcitxKey_3),
                    Key(FcitxKey_4), Key(FcitxKey_5), Key(FcitxKey_6),
                    Key(FcitxKey_7), Key(FcitxKey_8), Key(FcitxKey_9),
                    Key(FcitxKey_0)};
                static const KeyList keypadNumberKeys = {
                    Key(FcitxKey_KP_1), Key(FcitxKey_KP_2), Key(FcitxKey_KP_3),
                    Key(FcitxKey_KP_4), Key(FcitxKey_KP_5), Key(FcitxKey_KP_6),
                    Key(FcitxKey_KP_7), Key(FcitxKey_KP_8), Key(FcitxKey_KP_9),
                    Key(FcitxKey_KP_0)};
                int keyIndex = -1;
                if (int i =
                        key.keyListIndex(*config_.scrollMode->selectCandidate);
                    i >= 0 && i < 10) {
                    keyIndex = i;
                }
                if (keyIndex < 0 &&
                    *config_.scrollMode->useMainKeyboardNumberKeys) {
                    int i = key.keyListIndex(mainKeyboardNumberKeys);
                    if (i >= 0 && i < 10) {
                        keyIndex = i;
                    }
                }
                if (keyIndex < 0 && *config_.scrollMode->useKeypadNumberKeys) {
                    int i = key.keyListIndex(keypadNumberKeys);
                    if (i >= 0 && i < 10) {
                        keyIndex = i;
                    }
                }
                if (keyIndex >= 0) {
                    if (keyEvent.isRelease()) {
                        return;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                      window_->scroll_key_action(selectActions[keyIndex]);
                    });
                    return keyEvent.filterAndAccept();
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
                    if (key.checkKeyList(*pair.first)) {
                        if (!keyEvent.isRelease()) {
                            auto captured = pair.second;
                            dispatch_async(dispatch_get_main_queue(), ^{
                              window_->scroll_key_action(captured);
                            });
                        }
                        // Must not send release event to engine, which resets
                        // scroll mode.
                        return keyEvent.filterAndAccept();
                    }
                }
                if (key.checkKeyList(*config_.scrollMode->collapse)) {
                    if (keyEvent.isRelease()) {
                        return;
                    }
                    // Instead of directly calling collapse, let webview handle
                    // animation and call it.
                    dispatch_async(dispatch_get_main_queue(), ^{
                      window_->scroll_key_action(
                          candidate_window::scroll_key_action_t::collapse);
                    });
                    return keyEvent.filterAndAccept();
                }
                // Karabiner-Elements defines Hyper as Ctrl+Alt+Shift+Cmd, but
                // its combinations cause fcitx5-rime to reset candidates. This
                // is because librime's process_key returns 0 event if a key
                // event (Shift) is handled, thus fcitx5-rime can't use the
                // retval to decide update UI or not.
                static std::vector<Key> hyperModifiers = {
                    Key("Super+Super_L"),
                    Key("Control+Super+Control_L"),
                    Key("Control+Alt+Super+Alt_L"),
                    Key("Control+Alt+Shift+Super+Shift_L"),
                    Key("Alt+Shift+Super+Control_L"),
                    Key("Alt+Super+Shift_L"),
                    Key("Super+Alt_L"),
                    Key("Super_L"),
                    Key("Control+Control_L"),
                    Key("Control+Alt+Alt_L"),
                    Key("Control+Alt+Super+Super_L"),
                    Key("Alt+Super+Control_L"),
                }; // keys received by Fcitx5 when CapsLock (Hyper) is pressed
                if (*config_.scrollMode->optimizeForHyperKey &&
                    key.checkKeyList(hyperModifiers)) {
                    return keyEvent.filterAndAccept();
                }
            }
        });
}

void WebPanel::updateConfig() {
    setenv("BLUR", std::to_string(int(*config_.background->blur)).c_str(), 1);
    dispatch_async(dispatch_get_main_queue(), ^{
      window_->set_layout(config_.typography->layout.value());
      window_->set_theme(config_.basic->theme.value());
      window_->set_caret_text(config_.caret->style.value() == CaretStyle::Text
                                  ? config_.caret->text.value()
                                  : "");
      window_->set_highlight_mark_text(config_.highlight->markStyle.value() ==
                                               HighlightMarkStyle::Text
                                           ? config_.highlight->markText.value()
                                           : "");
      window_->set_native_blur(*config_.background->blur);
      // Keep CSS shadow as native may leave a ghost shadow of last frame when
      // typing fast.
      // window_->set_native_shadow(config_.background->shadow.value());
      auto style = configValueToJson(config_).dump();
      window_->set_style(style.c_str());
      window_->unload_plugins();
      using namespace candidate_window;
      uint64_t apis = (config_.advanced->unsafeAPI->curl.value() ? kCurl : 0);
      window_->set_api(apis);
      if (*config_.advanced->pluginNotice) {
          window_->load_plugins({*config_.advanced->plugins});
      }
    });
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
        readAsIni(raw, StandardPathsType::PkgData, themePath(themeName));
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
        safeSaveAsIni(raw, StandardPathsType::PkgData, themePath(themeName));
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
            // hack for rime
            if (*config_.typography->typographyAwarenessForIM) {
                // Allow -> to move highlight on horizontal+horizontal_tb.
                f5m_is_linear_layout =
                    (layout == candidate_window::layout_t::horizontal);
                f5m_is_vertical_rl =
                    (writingMode ==
                     candidate_window::writing_mode_t::vertical_rl);
                f5m_is_vertical_lr =
                    (writingMode ==
                     candidate_window::writing_mode_t::vertical_lr);
            } else {
                // Allow -> to move highlight on horizontal+horizontal_tb.
                f5m_is_linear_layout = false;
                f5m_is_vertical_rl = false;
                f5m_is_vertical_lr = false;
            }
            // Paging
            auto *pageableList = list->toPageable();
            if (pageableList) {
                pageable = *config_.typography->pagingButtonsStyle !=
                           PagingButtonsStyle::None;
                hasPrev = pageableList->hasPrev();
                hasNext = pageableList->hasNext();
            }
            // Scroll mode
            const auto &bulk = list->toBulk();
            if (layout == candidate_window::layout_t::horizontal &&
                writingMode ==
                    candidate_window::writing_mode_t::horizontal_tb &&
                *config_.scrollMode->enableScroll && bulk) {
                if (scrollState_ ==
                    candidate_window::scroll_state_t::scrolling) {
                    return expand();
                }
                if (*config_.scrollMode->autoExpand) {
                    scrollState_ = candidate_window::scroll_state_t::scrolling;
                    return expand();
                }
                // Disable scroll mode if all candidates are on the same page.
                if (hasPrev || hasNext) {
                    scrollState_ = candidate_window::scroll_state_t::ready;
                } else {
                    pageable = false;
                    scrollState_ = candidate_window::scroll_state_t::none;
                }
            } else {
                scrollState_ = candidate_window::scroll_state_t::none;
            }
            // Candidate actions
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
    bool followCaret = *config_.basic->followCaret;
    dispatch_async(dispatch_get_main_queue(), ^void() {
      if (show) {
          // MacosInputContext::updatePreeditImpl is executed before
          // WebPanel::update, so in main thread preedit UI update
          // happens before here.
          auto [x, y, height] =
              MacosInputContext::getCaretCoordinates(followCaret);
          window_->show(x, y, height);
      } else {
          window_->hide();
      }
    });
}

void WebPanel::scroll(int start, int count) {
    if (scrollState_ == candidate_window::scroll_state_t::none) {
        return;
    }
    if (start < 0) { // collapse
        return collapse();
    }
    auto ic = instance_->mostRecentInputContext();
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
                 instance_->outputFilter(ic, candidate.comment()).toString(),
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
}

void WebPanel::expand() {
    scroll(0, *config_.scrollMode->maxColumnCount *
                  (*config_.scrollMode->maxRowCount + 1));
}

void WebPanel::collapse() {
    auto ic = instance_->mostRecentInputContext();
    // Can't let update to set scrollState_, because it will keep scrollState_
    // scrolling.
    scrollState_ = candidate_window::scroll_state_t::ready;
    update(UserInterfaceComponent::InputPanel, ic);
}

void WebPanel::applyAppAccentColor(const std::string &accentColor) {
    auto captured = accentColor;
    dispatch_async(dispatch_get_main_queue(), ^{
      window_->apply_app_accent_color(captured);
    });
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(webpanel, fcitx::WebPanelFactory);
