#!/bin/zsh
set -xeu

user="$1"
tar_ball="$2"
INSTALL_DIR="/Library/Input Methods"
APP_DIR="$INSTALL_DIR/Fcitx5.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

ICON_FILE="fcitx.icns"
ICON_PATH="$RESOURCES_DIR/$ICON_FILE"
ICON_BAKUP="/tmp/$ICON_FILE"

# Backup maybe user-defined icon
if [[ -f "$ICON_PATH" ]]; then
  mv "$ICON_PATH" "$ICON_BAKUP"
fi

rm -rf "$APP_DIR/Contents/*"

tar xjvf "$tar_ball" -C "$INSTALL_DIR"
rm -f "$tar_ball"

if [[ -f "$ICON_BAKUP" ]]; then
  mv "$ICON_BAKUP" "$ICON_PATH"
fi

xattr -dr com.apple.quarantine "$APP_DIR"
codesign --force --sign - --deep "$APP_DIR"

cd "$RESOURCES_DIR"
# Switching out is necessary, otherwise it doesn't show menu
su -m "$user" -c "./switch_im com.apple.keylayout.ABC"
killall Fcitx5
su -m "$user" -c "./switch_im org.fcitx.inputmethod.Fcitx5.fcitx5"
