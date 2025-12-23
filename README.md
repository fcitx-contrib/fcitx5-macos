English
|
[中文](README.zh-CN.md)

# Fcitx5 macOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to macOS.

Please download [installer](https://github.com/fcitx-contrib/fcitx5-macos-installer) and read [documentation](https://fcitx-contrib.github.io/docs/).

## Build
Native build on Intel and Apple Silicon is supported.

This is NOT an Xcode project,
but Xcode >= 26 is needed for Swift compiler.

### Install dependencies
You may use [nvm](https://github.com/nvm-sh/nvm)
to install node, then

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
brew install cmake ninja extra-cmake-modules gettext librsvg
./scripts/install-deps.sh
npm i -g pnpm
pnpm --prefix=fcitx5-webview i
```

### Build with CMake
```sh
cmake -B build/$(uname -m) -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build/$(uname -m)
sudo cmake --install build/$(uname -m)
```
After the first time you execute `cmake --install`, you need to logout and login,
then add Fcitx5 in System Setttings -> Keyboard -> Input Sources, Chinese Simplified.

For installations afterwards, clicking `Restart` in Fcitx5 menu suffices.

You can also use `Cmd+Shift+B` in VSCode to execute a task.

### Code sign
Some features (e.g. notifications, core dump) require the app bundle be code-signed after installation:
```sh
./scripts/code-sign.sh
```

## Debug
### Console.app
* Check `Include Info Messages` and `Include Debug Messages` in `Action` menu.
* Put `FcitxLog` in `Search`.

### Log
`/tmp/Fcitx5.log` contains all log in Console.app,
plus those written to stderr by engines, e.g. rime.

### lldb
SSH into the mac from another device, then
```sh
$ /usr/bin/lldb
(lldb) process attach --name Fcitx5
```

### Core dump
```sh
sudo chmod 1777 /cores
sudo sysctl kern.coredump=1
ulimit -c unlimited  # only works for current shell
pkill Fcitx5; /Library/Input\ Methods/Fcitx5.app/Contents/MacOS/Fcitx5
```

When Fcitx5 crashes, it creates a ~10GB core file under `/cores`.
```sh
/usr/bin/lldb -c /cores/core.XXXX
(lldb) bt
```

## Plugins
Fcitx5 only packages keyboard engine.
To install other [engines or tables](https://github.com/fcitx-contrib/fcitx5-plugins),
use the built-in Plugin Manager.

## Translation

### Swift sources
To update .strings files for each supported locale, run
```sh
cmake --build build/$(uname -m) --target GenerateStrings
```

This will, e.g., update assets/zh-Hans/Localizable.strings, and then the translator can work on it.

### C++ sources
First, create assets/po/base.pot file:
```sh
cmake --build build/$(uname -m) --target pot
```

To add a new language, do
```sh
cd po && msginit -l <locale>
```

Then, use a PO file editor to translate strings.

Finally, to merge new strings into PO files, do
```sh
cd po && msgmerge -U <locale>.po base.pot
```

## Credits
* [fcitx5](https://github.com/fcitx/fcitx5): LGPL-2.1-or-later
* [fcitx5-android](https://github.com/fcitx5-android/fcitx5-android): LGPL-2.1-or-later
* [squirrel](https://github.com/rime/squirrel): GPL-3.0-only
* [swift-cmake-examples](https://github.com/apple/swift-cmake-examples): Apache-2.0
* [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON): MIT
* [AlertToast](https://github.com/elai950/AlertToast): MIT
* [pugixml](https://github.com/zeux/pugixml): MIT
* [webview](https://github.com/webview/webview): MIT
