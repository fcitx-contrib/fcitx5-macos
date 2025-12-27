#include "fcitx.h"

using json = nlohmann::json;

std::pair<bool, std::string> remoteHandler(const std::string_view command,
                                           const char *body) {
    return with_fcitx([&](Fcitx &fcitx) -> std::pair<bool, std::string> {
        if (command == "") {
            return {true, std::format("{}\n", fcitx.instance()->state())};
        }
        if (command == "c") {
            fcitx.instance()->deactivate();
            return {true, ""};
        }
        if (command == "o") {
            fcitx.instance()->activate();
            return {true, ""};
        }
        if (command == "t" || command == "T") {
            toggleInputMethod();
            return {true, ""};
        }
        if (command == "n") {
            return {true, imGetCurrentIMName() + "\n"};
        }
        if (command == "s") {
            try {
                auto j = json::parse(body);
                if (!j.is_array() || j.size() != 1 || !j[0].is_string()) {
                    return {false, "Invalid array\n"};
                }
                auto im = j[0].get<std::string>();
                imSetCurrentIM(im.c_str());
                return {true, ""};
            } catch (const std::exception &e) {
                return {false, "Invalid JSON\n"};
            }
        }
        return {false, "Unknown command\n"};
    });
}
