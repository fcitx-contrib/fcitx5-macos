#include <fcitx/inputpanel.h>

#include "../macosfrontend/macosfrontend.h"
#include "webpanel.h"

namespace fcitx {

WebPanel::WebPanel(Instance *instance)
    : instance_(instance),
      window_(std::make_unique<candidate_window::WebviewCandidateWindow>()) {
    window_->set_select_callback([this](size_t index) {
        auto ic = instance_->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return;
        try {
            list->candidate(index).select(ic);
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "select candidate index out of range";
        }
    });
    reloadConfig();
}

void WebPanel::updateConfig() {
    window_->set_layout(config_.layout.value());
    window_->set_theme(config_.theme.value());
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
        std::vector<std::string> candidates;
        std::vector<std::string> labels;
        int size = 0;
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
            size = list->size();
            for (int i = 0; i < size; i++) {
                candidates.emplace_back(
                    instance_
                        ->outputFilter(inputContext, list->candidate(i).text())
                        .toString());
                labels.emplace_back(list->label(i).toString());
            }
            highlighted = list->cursorIndex();
            // }
        }
        window_->set_candidates(candidates, labels, highlighted);
        updatePanelShowFlags(!candidates.empty(), PanelShowFlag::HasCandidates);
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
    dispatch_async(dispatch_get_main_queue(), ^void() {
      if (show) {
          if (auto ic = dynamic_cast<MacosInputContext *>(
                  instance_->mostRecentInputContext())) {
              // showPreeditCallback is executed before candidateListCallback,
              // so in main thread preedit UI update happens before here.
              auto [x, y] = ic->getCursorCoordinates();
              window_->show(x, y);
          }
      } else {
          window_->hide();
      }
    });
}

} // namespace fcitx
