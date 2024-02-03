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
        nlohmann::json j = getConfig("fcitx//config/global");
        assert(j.find("ERROR") == j.end());
    }
    {
        nlohmann::json j = getConfig("fcitx//addons/punctuation");
        assert(j.find("ERROR") == j.end());
    }
    {
        nlohmann::json j = getConfig("fcitx//addons/inputmethod/pinyin");
        assert(j.find("ERROR") == j.end());
    }

    // Can get available input methods.
    { std::cerr << imGetAvailableIMs() << std::endl; }

    stop_fcitx_thread();
}
