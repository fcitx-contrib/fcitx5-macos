set -e

if [[ -z $1 ]]; then
  ARCH=`uname -m`
else
  ARCH=$1
fi

EXTRACT_DIR=build/$ARCH/usr
mkdir -p $EXTRACT_DIR

deps=(
  default-icon-theme
  boost
  libexpat
  fmt
  libintl
  json
  json-c
  libuv
  libxkbcommon
  iso-codes
  xkeyboard-config
)

for dep in "${deps[@]}"; do
  file=$dep-$ARCH.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-prebuilder/releases/download/macos/$file
  tar xjvf cache/$file -C $EXTRACT_DIR
done
