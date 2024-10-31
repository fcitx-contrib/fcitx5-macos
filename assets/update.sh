#!/bin/zsh
set -xeu

user="$1"
tar_ball="$2"
INSTALL_DIR="/Library/Input Methods"
APP_DIR="$INSTALL_DIR/Fcitx5.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR/Contents/*"
tar xjvf "$tar_ball" -C "$INSTALL_DIR"
rm -f "$tar_ball"
xattr -dr com.apple.quarantine "$APP_DIR"
codesign --force --sign - --deep "$APP_DIR"

cd "$RESOURCES_DIR"
# Switching out is necessary, otherwise it doesn't show menu
# Not sure which one so try both.
su -m "$user" -c "./switch_im com.apple.keylayout.ABC"
su -m "$user" -c "./switch_im com.apple.keylayout.US"
killall Fcitx5
su -m "$user" -c "./switch_im org.fcitx.inputmethod.Fcitx5.fcitx5"
