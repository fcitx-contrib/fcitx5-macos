# Fcitx5 macOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to macOS.

WARNING: not ready for any non-developers.

## Build
Native build on Intel and Apple Silicon is supported.
Cross build from Intel to Apple Silicon is performed in [CI](.github/workflows/ci.yml).

### Install dependencies
```sh
brew install cmake ninja extra-cmake-modules gettext fmt libevent libxkbcommon iso-codes
```

### Build with CMake
```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
sudo cmake --install build
```

## Credits
* [fcitx5-android](https://github.com/fcitx5-android/fcitx5-android): LGPL-2.1-or-later
* [swift-cmake-examples](https://github.com/apple/swift-cmake-examples): Apache-2.0
