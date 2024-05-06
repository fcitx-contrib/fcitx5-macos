set -e

if [[ -z $1 ]]; then
  ARCH=`uname -m`
else
  ARCH=$1
fi

# This is the same with INSTALL_PREFIX of prebuilder
INSTALL_PREFIX=/tmp/fcitx5
mkdir -p $INSTALL_PREFIX

deps=(
  default-icon-theme
  expat
  fmt
  libintl
  json-c
  libuv
  libxkbcommon
  iso-codes
  xkeyboard-config
)

for dep in "${deps[@]}"; do
  file=$dep-$ARCH.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-macos-prebuilder/releases/download/latest/$file
  tar xjvf cache/$file -C $INSTALL_PREFIX
done
