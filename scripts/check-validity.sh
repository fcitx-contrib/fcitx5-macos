set -e

has_homebrew_deps=0
has_xcode_rpath=0

cd /Library/Input\ Methods/Fcitx5.app/Contents
libs=(MacOS/Fcitx5)
libs+=($(ls lib/libFcitx5{Config,Core,Utils}.dylib))
libs+=($(ls lib/fcitx5/*.so))
libs+=(lib/fcitx5/libexec/comp-spell-dict)

for lib in "${libs[@]}"; do
  if otool -L $lib | grep '/usr/local\|/opt/homebrew'; then
    otool -L $lib
    has_homebrew_deps=1
  fi
  if otool -l $lib | grep -A2 LC_RPATH | grep Xcode; then
    otool -l $lib | grep -A2 LC_RPATH
    has_xcode_rpath=2
  fi
done

exit $((has_homebrew_deps + has_xcode_rpath))
