#include "fcitx-public.h"
#include "config/config-public.h"
#include <nlohmann/json.hpp>
#include <unistd.h>

int main() {
    start_fcitx_thread();
    sleep(1);
    
    // Can get information about input methods.
    all_input_methods();
    
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
    
    stop_fcitx_thread();
}
