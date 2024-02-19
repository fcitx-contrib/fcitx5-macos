#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

#include "webview_candidate_window.hpp"

namespace fcitx {

enum class PanelShowFlag : int;
using PanelShowFlags = fcitx::Flags<PanelShowFlag>;

class WebPanel final : public UserInterface {
public:
    WebPanel(Instance *);
    ~WebPanel() = default;

    Instance *instance() { return instance_; }

    bool available() override { return true; }
    void suspend() override {}
    void resume() override {}
    void update(UserInterfaceComponent component,
                InputContext *inputContext) override;

    void updateInputPanel(const Text &preedit, const Text &auxUp,
                          const Text &auxDown);

private:
    Instance *instance_;
    std::unique_ptr<candidate_window::CandidateWindow> window_;

    void showAsync(bool show);
    PanelShowFlags panelShow_;
    inline void updatePanelShowFlags(bool condition, PanelShowFlag flag) {
        if (condition)
            panelShow_ |= flag;
        else
            panelShow_ = panelShow_.unset(flag);
    }
};

class WebPanelFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new WebPanel(manager->instance());
    }
};

enum class PanelShowFlag : int {
    HasAuxUp = 1,
    HasAuxDown = 1 << 1,
    HasPreedit = 1 << 2,
    HasCandidates = 1 << 3
};

} // namespace fcitx
