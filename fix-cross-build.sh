# Currently not used, but will be useful once GitHub drops macOS x86 runners
set -e
if [[ -z "$CI" ]]; then
  exit 1
fi
# Don't hide cmake target dependency issue by rebuild
if [[ $1 == x86_64 ]]; then
  exit 1
fi
# HACK: temporarily replace comp-spell-dict from last successful build of native fcitx5
wget https://github.com/fcitx-contrib/fcitx5-macos/releases/download/latest/Fcitx5-x86_64.tar.bz2
sudo tar xjvf Fcitx5-x86_64.tar.bz2 -C "/Library/Input Methods"
mv build/fcitx5/src/modules/spell/comp-spell-dict{,.bak}
cp "/Library/Input Methods/Fcitx5.app/Contents/lib/fcitx5/libexec/comp-spell-dict" build/fcitx5/src/modules/spell/comp-spell-dict
cmake --build build
mv build/fcitx5/src/modules/spell/comp-spell-dict{.bak,}
sudo rm -r "/Library/Input Methods/Fcitx5.app"
