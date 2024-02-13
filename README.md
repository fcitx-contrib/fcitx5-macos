# Fcitx5 macOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to macOS.

WARNING: not ready for any non-developers.

## Build
Native build on Intel and Apple Silicon is supported.

### Install dependencies
You may use [nvm](https://github.com/nvm-sh/nvm)
to install node, then

```sh
brew install cmake ninja extra-cmake-modules gettext iso-codes xkeyboardconfig nlohmann-json
./install-deps.sh
npm i -g pnpm
pnpm --prefix=fcitx5-webview i
```

### Build with CMake
```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
sudo cmake --install build
```

### Code sign
Some features (e.g. notifications) require the app bundle be code-signed after installation:
```
sudo /usr/bin/codesign --force --sign - --deep /Library/Input\ Methods/Fcitx5.app
```

## Debug
### Console.app
* Check `Include Info Messages` and `Include Debug Messages` in `Action` menu.
* Put `FcitxLog` in `Search`.

### lldb
SSH into the mac from another device, then
```sh
$ /usr/bin/lldb
(lldb) process attach --name Fcitx5
```

## Plugins
Fcitx5 only packges keyboard engine.
To install other engines, see [fcitx5-macos-plugins](https://github.com/fcitx-contrib/fcitx5-macos-plugins).

## Credits
* [fcitx5-android](https://github.com/fcitx5-android/fcitx5-android): LGPL-2.1-or-later
* [squirrel](https://github.com/rime/squirrel): GPL-3.0-only
* [swift-cmake-examples](https://github.com/apple/swift-cmake-examples): Apache-2.0
