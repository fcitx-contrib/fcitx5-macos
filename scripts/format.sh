find keycode macosfrontend macosnotifications webpanel src tests -name '*.cpp' -o -name '*.h' | xargs clang-format -i -style=file:fcitx5/.clang-format
clang-format -i macosfrontend/pasteboard.mm
swift-format format --configuration .swift-format.json --in-place $(find macosfrontend macosnotifications src assets -name '*.swift')
