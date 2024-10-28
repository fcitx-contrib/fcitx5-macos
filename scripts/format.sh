find macosfrontend macosnotifications webpanel src tests -name '*.cpp' -o -name '*.h' | xargs clang-format -i -style=file:fcitx5/.clang-format
clang-format -i macosfrontend/pasteboard.mm
