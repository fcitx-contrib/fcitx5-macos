set -e
if [[ -z "$CI" ]]; then
  exit 1
fi
# HACK: temporarily replace comp-spell-dict from last successful build of native fcitx5
wget https://github.com/fcitx-contrib/fcitx5-macos/releases/download/latest/Fcitx5-x86_64.dmg
hdiutil attach Fcitx5-x86_64.dmg
sudo cp -r /Volumes/Fcitx5/{Fcitx5.app,"Input Methods"}
mv build/fcitx5/src/modules/spell/comp-spell-dict{,.bak}
cp "/Library/Input Methods/Fcitx5.app/Contents/lib/fcitx5/libexec/comp-spell-dict" build/fcitx5/src/modules/spell/comp-spell-dict
cmake --build build
mv build/fcitx5/src/modules/spell/comp-spell-dict{.bak,}
sudo rm -r "/Library/Input Methods/Fcitx5.app"
