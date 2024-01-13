# Fcitx5 macOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to macOS.

WARNING: not ready for any non-developers.

## Build
Native build on Intel and Apple Silicon is supported.
Cross build from Intel to Apple Silicon is performed in [CI](.github/workflows/ci.yml).

### Install dependencies
```sh
brew install cmake ninja extra-cmake-modules gettext iso-codes xkeyboardconfig
./install-deps.sh
```

### Build with CMake
```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
sudo cmake --install build
```

### Code sign
Some features require the app bundle be code-signed after installation:
```
sudo /usr/bin/codesign --force --sign $KEY --timestamp --options runtime --deep /Library/Input\ Methods/Fcitx5.app/
```
where `$KEY` can be `-` for ad-hoc signing.

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
