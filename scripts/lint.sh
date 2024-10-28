set -e

find macosfrontend macosnotifications webpanel src tests -name '*.cpp' -o -name '*.h' | xargs clang-format -Werror --dry-run -style=file:fcitx5/.clang-format
clang-format -Werror --dry-run macosfrontend/pasteboard.mm
swift-format lint --configuration .swift-format.json -rs macosfrontend macosnotifications src assets
./scripts/check-code-style.sh
file assets/zh-Hans.lproj/Localizable.strings | grep UTF-16
