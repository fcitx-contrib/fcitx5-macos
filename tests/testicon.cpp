#include "fcitx/icontheme.h"
#include "../src/fcitx.h"

void test_find_icon() {
    auto iconTheme = std::make_unique<fcitx::IconTheme>("hicolor");
    auto path = iconTheme->findIconPath("fcitx_rime_deploy", 48, 1, {".png"});
    FCITX_ASSERT(!path.empty());
}

int main() {
    Fcitx::shared();
    test_find_icon();
    return 0;
}
