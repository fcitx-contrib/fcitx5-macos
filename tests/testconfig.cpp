#include <unistd.h>
#include <iostream>
#include <nlohmann/json.hpp>
#include "fcitx-public.h"
#include "fcitx-utils/log.h"
#include "config/config-public.h"

int main() {
    start_fcitx_thread("C");
    sleep(1);

    // Can get information about input methods.
    imGetGroups();

    // Can get config.
    {
        auto j = nlohmann::json::parse(getConfig("fcitx://config/global"));
        FCITX_ASSERT(j.is_object() && j.find("ERROR") == j.end());
    }
    {
        auto j =
            nlohmann::json::parse(getConfig("fcitx://config/addon/unicode"));
        FCITX_ASSERT(j.is_object() && j.find("ERROR") == j.end());
    }
    {
        auto j = nlohmann::json::parse(
            getConfig("fcitx://config/inputmethod/keyboard-us"));
        FCITX_ASSERT(j.is_object() && j.find("ERROR") == j.end());
    }

    // Can get available input methods.
    std::cerr << imGetAvailableIMs() << std::endl;

    // Can set config
    std::vector<std::string> values{"False", "True"};
    for (const auto &value : values) {
        nlohmann::json j{{"Behavior", {{"ActiveByDefault", value}}}};
        FCITX_ASSERT(setConfig("fcitx://config/global", j.dump().c_str()));
        auto updated =
            nlohmann::json::parse(getConfig("fcitx://config/global"));
        for (const auto &child : updated["Children"]) {
            if (child["Option"] == "Behavior") {
                for (const auto &grand_child : child["Children"]) {
                    if (grand_child["Option"] == "ActiveByDefault") {
                        FCITX_ASSERT(grand_child["Value"].get<std::string>() ==
                                     value);
                        break;
                    }
                }
                break;
            }
        }
    }

    stop_fcitx_thread();
}
