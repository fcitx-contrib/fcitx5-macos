#include <unistd.h>
#include <iostream>
#include <nlohmann/json.hpp>
#include "fcitx-public.h"
#include "config/config-public.h"

int main() {
    start_fcitx_thread();
    sleep(1);

    // Can get information about input methods.
    imGetGroups();

    // Can get config.
    {
        auto j = nlohmann::json::parse(getConfig("fcitx://config/global"));
        assert(j.is_object() && j.find("ERROR") == j.end());
    }
    {
        auto j = nlohmann::json::parse(
            getConfig("fcitx://config/addon/punctuation"));
        assert(j.is_object() && j.find("ERROR") == j.end());
    }
    {
        auto j = nlohmann::json::parse(
            getConfig("fcitx://config/inputmethod/pinyin"));
        assert(j.is_object() && j.find("ERROR") == j.end());
    }

    // Can get available input methods.
    { std::cerr << imGetAvailableIMs() << std::endl; }

    // Can set config
    std::vector<std::string> values{"False", "True"};
    for (const auto &value : values) {
        nlohmann::json j{{"Behavior", {{"ActiveByDefault", value}}}};
        assert(setConfig("fcitx://config/global", j.dump().c_str()));
        auto updated =
            nlohmann::json::parse(getConfig("fcitx://config/global"));
        assert(updated["Behavior"]["ActiveByDefault"]["Value"]
                   .get<std::string>() == value);
    }

    stop_fcitx_thread();
}
